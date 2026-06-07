// lib/services/feedback_service.dart
// 사용자 피드백을 Firestore 'feedbacks' 컬렉션에 저장

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  FeedbackService._();
  static final instance = FeedbackService._();

  final _db = FirebaseFirestore.instance;

  /// 피드백 제출
  /// [type] : 'bug' | 'feature' | 'general'
  /// [content] : 피드백 본문
  /// [rating] : 별점 1~5 (null 가능)
  Future<void> submitFeedback({
    required String type,
    required String content,
    int? rating,
  }) async {
    if (content.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    await _db.collection('feedbacks').add({
      'uid': uid,
      'type': type,
      'content': content.trim(),
      'rating': rating,
      'appVersion': '1.0.0',
      'platform': 'android',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}