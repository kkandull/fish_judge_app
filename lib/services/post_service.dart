// 커뮤니티 게시글 관련 모든 Firestore 작업.
// 인덱스 없이 동작하도록 클라이언트 필터링 사용.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';
import '../utils/image_encoder.dart';
import '../utils/profanity_filter.dart';
import 'auth_service.dart';
import 'block_service.dart';

/// 게시글 정렬 옵션
enum PostSortOption {
  latest('최신순', '🕐'),
  popular('인기순', '🔥'),
  mostCommented('댓글 많은 순', '💬');

  final String label;
  final String emoji;
  const PostSortOption(this.label, this.emoji);
}

/// 게시글 카테고리
enum PostCategory {
  all('전체', null, ''),
  catch_('조과 자랑', 'catch', ''),
  question('질문', 'question', ''),
  info('정보 공유', 'info', ''),
  myPosts('내 글', null, '');

  final String label;
  final String? value;
  final String emoji;
  const PostCategory(this.label, this.value, this.emoji);
}

class PostService {
  static final PostService instance = PostService._();
  PostService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');

  // 게시글 작성
  
  Future<String> createPost({
    required String title,
    required String body,
    File? image,
    String? linkedFishName,
    List<String> imageBase64Thumbs = const [],
    List<String> imageBase64Fulls = const [],
    String category = 'catch',
    List<String> tags = const [],
  }) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final nickname = await AuthService.instance.getNickname();
    if (nickname == null) throw Exception('닉네임을 먼저 설정해주세요');

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty) throw Exception('제목을 입력해주세요');
    if (trimmedTitle.length > 50) throw Exception('제목은 50자 이내로 작성해주세요');
    if (trimmedBody.isEmpty) throw Exception('내용을 입력해주세요');
    if (trimmedBody.length > 2000) throw Exception('내용은 2000자 이내로 작성해주세요');

    final titleCheck = ProfanityFilter.validate(trimmedTitle);
    if (titleCheck != null) throw Exception('제목: $titleCheck');
    final bodyCheck = ProfanityFilter.validate(trimmedBody);
    if (bodyCheck != null) throw Exception('내용: $bodyCheck');

    final post = CommunityPost(
      id: '',
      uid: uid,
      nickname: nickname,
      title: trimmedTitle,
      body: trimmedBody,
      imageBase64Thumbs: imageBase64Thumbs,
      imageBase64Fulls: imageBase64Fulls,
      linkedFishName: linkedFishName,
      category: category,
      createdAt: DateTime.now(),
      tags: tags,
    );

    final docRef = await _posts.add(post.toCreateMap());
    return docRef.id;
  }

  // 게시글 조회 — 통합 검색/정렬/카테고리

  /// 게시글 목록 실시간 스트림
  ///
  /// [searchKeyword]: 제목/본문/닉네임/어종에서 매칭
  /// [sort]: 최신순/인기순/댓글많은순
  /// [category]: 전체/조과/질문/정보/내글
  /// [refreshTrigger]: bump하면 스트림을 끊지 않고 재구독 유도 (깜빡임 방지)
  Stream<List<CommunityPost>> watchPosts({
    int limit = 50,
    String searchKeyword = '',
    PostSortOption sort = PostSortOption.latest,
    PostCategory category = PostCategory.all,
    int refreshTrigger = 0, // ✅ 커뮤니티 깜빡임 방지용
  }) async* {
    final blockedUids = await BlockService.getBlockedUids();
    final myUid = AuthService.instance.uid;
    final keyword = searchKeyword.trim().toLowerCase();

    yield* _posts
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .snapshots()
        .map((snap) {
          var posts = snap.docs.map(CommunityPost.fromDoc).toList();

          // 1. 신고된 글 제거
          posts = posts.where((p) => !p.isReported).toList();

          // 2. 차단 사용자 제거
          posts = posts.where((p) => !blockedUids.contains(p.uid)).toList();

          // 3. 카테고리 필터
          if (category == PostCategory.myPosts && myUid != null) {
            posts = posts.where((p) => p.uid == myUid).toList();
          } else if (category.value != null) {
            posts = posts.where((p) => p.category == category.value).toList();
          }

          // 4. 검색어 필터 (lowercase contains)
          if (keyword.isNotEmpty) {
            posts = posts.where((p) {
              final target = '${p.title} ${p.body} ${p.nickname} ${p.linkedFishName ?? ''}'.toLowerCase();
              return target.contains(keyword);
            }).toList();
          }

          // 5. 정렬
          switch (sort) {
            case PostSortOption.latest:
              break;
            case PostSortOption.popular:
              posts.sort((a, b) {
                final cmp = b.likeCount.compareTo(a.likeCount);
                if (cmp != 0) return cmp;
                return b.createdAt.compareTo(a.createdAt);
              });
              break;
            case PostSortOption.mostCommented:
              posts.sort((a, b) {
                final cmp = b.commentCount.compareTo(a.commentCount);
                if (cmp != 0) return cmp;
                return b.createdAt.compareTo(a.createdAt);
              });
              break;
          }

          return posts.take(limit).toList();
        });
  }

  Future<CommunityPost?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return CommunityPost.fromDoc(doc);
  }

  Stream<CommunityPost?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommunityPost.fromDoc(doc);
    });
  }

  // 게시글 삭제

  Future<void> deletePost(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    
    final post = await getPost(postId);
    if (post == null) throw Exception('게시글이 없어요');
    if (post.uid != uid) throw Exception('본인 게시글만 삭제할 수 있어요');
    
    await _posts.doc(postId).delete();
  }

  // 좋아요

  Future<bool> toggleLike(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final likeRef = _posts.doc(postId).collection('likes').doc(uid);
    final postRef = _posts.doc(postId);

    return _db.runTransaction((tx) async {
      final likeDoc = await tx.get(likeRef);
      
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        return false;
      } else {
        tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        return true;
      }
    });
  }

  Future<bool> hasLiked(String postId) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return false;
    
    final doc = await _posts.doc(postId).collection('likes').doc(uid).get();
    return doc.exists;
  }

  Stream<bool> watchLiked(String postId) {
    final uid = AuthService.instance.uid;
    if (uid == null) return Stream.value(false);
    
    return _posts.doc(postId).collection('likes').doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // 댓글

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
  
  // 신고

  Future<void> reportPost(String postId, String reason) async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) throw Exception('신고 사유를 입력해주세요');
    if (trimmedReason.length > 200) throw Exception('신고 사유는 200자 이내로 작성해주세요');

    final existing = await _reports
        .where('postId', isEqualTo: postId)
        .where('reporterUid', isEqualTo: uid)
        .limit(1)
        .get();
    
    if (existing.docs.isNotEmpty) {
      throw Exception('이미 신고한 게시글이에요');
    }

    await _reports.add({
      'postId': postId,
      'reporterUid': uid,
      'reason': trimmedReason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final allReports = await _reports
        .where('postId', isEqualTo: postId)
        .get();
    
    if (allReports.docs.length >= 3) {
      await _posts.doc(postId).update({'isReported': true});
    }
  }
}