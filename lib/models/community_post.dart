// lib/models/community_post.dart
//
// 커뮤니티 게시글 모델.
// 이미지는 Base64로 인코딩되어 Firestore 안에 저장됨.
// - imageBase64Thumb: 240px Q70 (~15KB) - 목록용
// - imageBase64Full:  800px Q75 (~250KB) - 상세용
//
// Firestore 1MB 문서 한도 안에서 안전한 크기.

import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String uid;
  final String nickname;
  final String title;
  final String body;
  final String? imageBase64Thumb;
  final String? imageBase64Full;
  final String? linkedFishName; // 도감에서 가져온 어종 (선택)
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final List<String> tags;
  final bool isReported;
  
  CommunityPost({
    required this.id,
    required this.uid,
    required this.nickname,
    required this.title,
    required this.body,
    this.imageBase64Thumb,
    this.imageBase64Full,
    this.linkedFishName,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.tags = const [],
    this.isReported = false,
  });
  
  /// Firestore 문서 → 객체
  factory CommunityPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'] as Timestamp?;
    return CommunityPost(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '익명',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageBase64Thumb: data['imageBase64Thumb'] as String?,
      imageBase64Full: data['imageBase64Full'] as String?,
      linkedFishName: data['linkedFishName'] as String?,
      createdAt: ts?.toDate() ?? DateTime.now(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(data['tags'] ?? const []),
      isReported: data['isReported'] as bool? ?? false,
    );
  }
  
  /// 새 게시글 작성 시 Firestore에 저장할 Map
  /// (id 제외, 서버 타임스탬프 사용)
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'nickname': nickname,
    'title': title,
    'body': body,
    'imageBase64Thumb': imageBase64Thumb,
    'imageBase64Full': imageBase64Full,
    'linkedFishName': linkedFishName,
    'createdAt': FieldValue.serverTimestamp(),
    'likeCount': 0,
    'commentCount': 0,
    'tags': tags,
    'isReported': false,
  };
  
  /// 시간 표시 ("3분 전", "어제", 등)
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}월 ${createdAt.day}일';
  }
  
  /// 사진 있음?
  bool get hasImage => imageBase64Thumb != null && imageBase64Thumb!.isNotEmpty;
}

/// 댓글 모델
class Comment {
  final String id;
  final String uid;
  final String nickname;
  final String body;
  final DateTime createdAt;
  
  Comment({
    required this.id,
    required this.uid,
    required this.nickname,
    required this.body,
    required this.createdAt,
  });
  
  factory Comment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'] as Timestamp?;
    return Comment(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '익명',
      body: data['body'] as String? ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }
  
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분';
    if (diff.inHours < 24) return '${diff.inHours}시간';
    if (diff.inDays < 7) return '${diff.inDays}일';
    return '${createdAt.month}/${createdAt.day}';
  }
}
