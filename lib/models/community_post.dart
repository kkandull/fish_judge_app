// lib/models/community_post.dart
//
// 커뮤니티 게시글 모델.
// 이미지는 Base64로 인코딩되어 Firestore 안에 저장됨.

import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String uid;
  final String nickname;
  final String title;
  final String body;
  final List<String> imageBase64Thumbs;  // 썸네일 목록
  final List<String> imageBase64Fulls;   // 본 이미지 목록
  final String? linkedFishName;
  final String category; // ✅ 'catch' / 'question' / 'info'
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
    this.imageBase64Thumbs = const [],
    this.imageBase64Fulls = const [],
    this.linkedFishName,
    this.category = 'catch',
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.tags = const [],
    this.isReported = false,
  });
  
  factory CommunityPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'] as Timestamp?;
    return CommunityPost(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '익명',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageBase64Thumbs: data['imageBase64Thumbs'] != null
        ? List<String>.from(data['imageBase64Thumbs'])
        : (data['imageBase64Thumb'] != null ? [data['imageBase64Thumb'] as String] : []),
      imageBase64Fulls: data['imageBase64Fulls'] != null
        ? List<String>.from(data['imageBase64Fulls'])
        : (data['imageBase64Full'] != null ? [data['imageBase64Full'] as String] : []),
      linkedFishName: data['linkedFishName'] as String?,
      category: data['category'] as String? ?? 'catch', // ✅ 기존 글은 catch로 fallback
      createdAt: ts?.toDate() ?? DateTime.now(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(data['tags'] ?? const []),
      isReported: data['isReported'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'nickname': nickname,
    'title': title,
    'body': body,
    'imageBase64Thumbs': imageBase64Thumbs,
    'imageBase64Fulls': imageBase64Fulls,
    'linkedFishName': linkedFishName,
    'category': category,
    'createdAt': FieldValue.serverTimestamp(),
    'likeCount': 0,
    'commentCount': 0,
    'tags': tags,
    'isReported': false,
  };
  
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}월 ${createdAt.day}일';
  }
  
  bool get hasImage => imageBase64Thumbs.isNotEmpty;
  /// 카테고리 라벨
  String get categoryLabel {
    switch (category) {
      case 'question': return '❓ 질문';
      case 'info': return '💡 정보 공유';
      case 'catch':
      default: return '🎣 조과 자랑';
    }
  }
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