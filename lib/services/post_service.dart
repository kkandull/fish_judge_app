// lib/services/post_service.dart
//
// 커뮤니티 게시글 관련 모든 Firestore 작업.
//
// 데이터 구조:
//   posts/{postId}                           — 게시글
//   posts/{postId}/comments/{commentId}      — 댓글
//   posts/{postId}/likes/{userId}            — 좋아요
//   reports/{reportId}                       — 신고
//
// ⚠️ 인덱스 없이 동작하도록 클라이언트 필터링 사용.
// 데이터가 많아지면 (1000+) 인덱스 추가 권장.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';
import '../utils/image_encoder.dart';
import '../utils/profanity_filter.dart';
import 'auth_service.dart';
import 'block_service.dart';

class PostService {
  static final PostService instance = PostService._();
  PostService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 게시글 작성
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// 새 게시글 작성
  /// 
  /// 반환: 생성된 postId
  Future<String> createPost({
    required String title,
    required String body,
    File? image,
    String? linkedFishName,
    List<String> tags = const [],
  }) async {
    // 1. 인증 확인
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final nickname = await AuthService.instance.getNickname();
    if (nickname == null) throw Exception('닉네임을 먼저 설정해주세요');

    // 2. 검증
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty) throw Exception('제목을 입력해주세요');
    if (trimmedTitle.length > 50) throw Exception('제목은 50자 이내로 작성해주세요');
    if (trimmedBody.isEmpty) throw Exception('내용을 입력해주세요');
    if (trimmedBody.length > 2000) throw Exception('내용은 2000자 이내로 작성해주세요');

    // 욕설 검사
    final titleCheck = ProfanityFilter.validate(trimmedTitle);
    if (titleCheck != null) throw Exception('제목: $titleCheck');
    final bodyCheck = ProfanityFilter.validate(trimmedBody);
    if (bodyCheck != null) throw Exception('내용: $bodyCheck');

    // 3. 이미지 인코딩
    String? thumb, full;
    if (image != null) {
      try {
        final encoded = await ImageEncoder.encodeImage(image);
        thumb = encoded['thumbnail'];
        full = encoded['full'];
      } catch (e) {
        throw Exception('이미지 처리 실패: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }

    // 4. Firestore에 저장
    final post = CommunityPost(
      id: '',
      uid: uid,
      nickname: nickname,
      title: trimmedTitle,
      body: trimmedBody,
      imageBase64Thumb: thumb,
      imageBase64Full: full,
      linkedFishName: linkedFishName,
      createdAt: DateTime.now(),
      tags: tags,
    );

    final docRef = await _posts.add(post.toCreateMap());
    return docRef.id;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 게시글 조회
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 게시글 목록 실시간 스트림 (최신순)
  /// 
  /// 인덱스 없이 동작: orderBy만 사용하고 isReported / 차단 필터는 클라이언트에서.
  /// 차단한 사용자 게시글도 자동 필터링.
  Stream<List<CommunityPost>> watchPosts({int limit = 30}) async* {
    final blockedUids = await BlockService.getBlockedUids();
    
    // ⚠️ where 제거 — 인덱스 없이 단순 orderBy만 사용
    yield* _posts
        .orderBy('createdAt', descending: true)
        .limit(limit * 2) // 필터링으로 줄어들 수 있어 여유 있게
        .snapshots()
        .map((snap) => snap.docs
            .map(CommunityPost.fromDoc)
            .where((p) => !p.isReported)              // 신고된 글 제외
            .where((p) => !blockedUids.contains(p.uid)) // 차단 사용자 제외
            .take(limit) // 원하는 개수만큼만
            .toList());
  }

  /// 단일 게시글 가져오기
  Future<CommunityPost?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return CommunityPost.fromDoc(doc);
  }

  /// 단일 게시글 실시간 스트림 (좋아요/댓글 카운트 동기화용)
  Stream<CommunityPost?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommunityPost.fromDoc(doc);
    });
  }

  /// 본인이 작성한 게시글 목록
  /// 
  /// where(uid) + orderBy(createdAt) 복합 인덱스 필요할 수 있음.
  /// 처음 호출 시 에러 나면 콘솔의 자동 생성 링크 클릭.
  Stream<List<CommunityPost>> watchMyPosts() {
    final uid = AuthService.instance.uid;
    if (uid == null) return Stream.value([]);
    
    // uid로만 필터, 정렬은 클라이언트에서
    return _posts
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(CommunityPost.fromDoc).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 게시글 삭제
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 게시글 삭제 (본인만 가능, 보안 규칙에서도 검증)
  Future<void> deletePost(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    
    final post = await getPost(postId);
    if (post == null) throw Exception('게시글이 없어요');
    if (post.uid != uid) throw Exception('본인 게시글만 삭제할 수 있어요');
    
    // 댓글 / 좋아요 서브컬렉션은 자동 삭제 안 됨
    // 일단 게시글만 삭제 (서브컬렉션은 클라우드 함수로 처리 - 발표 단계에선 생략)
    await _posts.doc(postId).delete();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 좋아요
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 좋아요 토글 (눌렀으면 취소, 안 눌렀으면 추가)
  /// 
  /// 반환: 토글 후 상태 (true = 좋아요 됨, false = 취소됨)
  Future<bool> toggleLike(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final likeRef = _posts.doc(postId).collection('likes').doc(uid);
    final postRef = _posts.doc(postId);

    return _db.runTransaction((tx) async {
      final likeDoc = await tx.get(likeRef);
      
      if (likeDoc.exists) {
        // 좋아요 취소
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        return false;
      } else {
        // 좋아요 추가
        tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        return true;
      }
    });
  }

  /// 사용자가 이 게시글에 좋아요 했는지 확인
  Future<bool> hasLiked(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return false;
    
    final doc = await _posts.doc(postId).collection('likes').doc(uid).get();
    return doc.exists;
  }

  /// 좋아요 여부 실시간 스트림
  Stream<bool> watchLiked(String postId) {
    final uid = AuthService.instance.uid;
    if (uid == null) return Stream.value(false);
    
    return _posts.doc(postId).collection('likes').doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 댓글
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 댓글 작성
  Future<void> addComment(String postId, String body) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final nickname = await AuthService.instance.getNickname();
    if (nickname == null) throw Exception('닉네임을 먼저 설정해주세요');

    final trimmed = body.trim();
    if (trimmed.isEmpty) throw Exception('댓글을 입력해주세요');
    if (trimmed.length > 500) throw Exception('댓글은 500자 이내로 작성해주세요');

    final check = ProfanityFilter.validate(trimmed);
    if (check != null) throw Exception(check);

    final postRef = _posts.doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await _db.runTransaction((tx) async {
      tx.set(commentRef, {
        'uid': uid,
        'nickname': nickname,
        'body': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  /// 댓글 목록 실시간 스트림 (오래된 순)
  Stream<List<Comment>> watchComments(String postId) async* {
    final blockedUids = await BlockService.getBlockedUids();
    
    yield* _posts.doc(postId).collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map(Comment.fromDoc)
            .where((c) => !blockedUids.contains(c.uid))
            .toList());
  }

  /// 댓글 삭제 (본인만)
  Future<void> deleteComment(String postId, String commentId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    
    final postRef = _posts.doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);
    
    await _db.runTransaction((tx) async {
      final comment = await tx.get(commentRef);
      if (!comment.exists) throw Exception('댓글이 없어요');
      if (comment.data()?['uid'] != uid) throw Exception('본인 댓글만 삭제할 수 있어요');
      
      tx.delete(commentRef);
      tx.update(postRef, {'commentCount': FieldValue.increment(-1)});
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 신고
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 게시글 신고
  /// 
  /// 같은 게시글에 신고 3건 누적 시 자동으로 isReported=true 처리
  /// (목록에서 자동 숨겨짐)
  Future<void> reportPost(String postId, String reason) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) throw Exception('신고 사유를 입력해주세요');
    if (trimmedReason.length > 200) throw Exception('신고 사유는 200자 이내로 작성해주세요');

    // 동일 사용자가 같은 게시글 중복 신고 방지
    final existing = await _reports
        .where('postId', isEqualTo: postId)
        .where('reporterUid', isEqualTo: uid)
        .limit(1)
        .get();
    
    if (existing.docs.isNotEmpty) {
      throw Exception('이미 신고한 게시글이에요');
    }

    // 신고 기록
    await _reports.add({
      'postId': postId,
      'reporterUid': uid,
      'reason': trimmedReason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 같은 게시글 신고 3건 이상이면 자동 숨김
    final allReports = await _reports
        .where('postId', isEqualTo: postId)
        .get();
    
    if (allReports.docs.length >= 3) {
      await _posts.doc(postId).update({'isReported': true});
    }
  }
}