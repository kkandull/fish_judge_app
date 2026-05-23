// lib/services/auth_service.dart
//
// 익명 로그인 + 닉네임 관리.
// Firebase Anonymous Auth를 사용해 회원가입 없이 사용자 식별.
// 닉네임은 한 번 정하면 변경 불가 (스팸/혼란 방지).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  /// 현재 사용자 UID
  String? get uid => _auth.currentUser?.uid;

  /// 로그인 여부
  bool get isLoggedIn => _auth.currentUser != null;

  /// 익명 로그인 (이미 되어있으면 그대로 반환)
  Future<User> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser!;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// 닉네임 설정 여부 확인 (Firestore에 users/{uid} 문서 있는지)
  Future<bool> hasNickname() async {
    final uid = this.uid;
    if (uid == null) return false;

    // 로컬 캐시 먼저
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('nickname') != null) return true;

    // Firestore 확인
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['nickname'] != null) {
      // 캐시에 저장
      await prefs.setString('nickname', doc.data()!['nickname'] as String);
      return true;
    }
    return false;
  }

  /// 닉네임 가져오기
  Future<String?> getNickname() async {
    final uid = this.uid;
    if (uid == null) return null;

    // 로컬 캐시
    final prefs = await SharedPreferences.getInstance();
    var nickname = prefs.getString('nickname');
    if (nickname != null) return nickname;

    // Firestore에서 가져오기
    final doc = await _db.collection('users').doc(uid).get();
    nickname = doc.data()?['nickname'] as String?;
    if (nickname != null) await prefs.setString('nickname', nickname);
    return nickname;
  }

  /// 닉네임 중복 확인
  Future<bool> isNicknameAvailable(String nickname) async {
    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  /// 닉네임 설정 (최초 1회만)
  Future<void> setNickname(String nickname) async {
    final uid = this.uid;
    if (uid == null) throw Exception('로그인이 필요해요');

    final trimmed = nickname.trim();
    if (trimmed.length < 2 || trimmed.length > 10) {
      throw Exception('닉네임은 2~10자로 입력해주세요');
    }

    // 특수문자 차단 (한글/영문/숫자만 허용)
    if (!RegExp(r'^[a-zA-Z0-9가-힣]+$').hasMatch(trimmed)) {
      throw Exception('한글, 영문, 숫자만 사용 가능해요');
    }

    // 중복 체크
    if (!await isNicknameAvailable(trimmed)) {
      throw Exception('이미 사용 중인 닉네임이에요');
    }

    // 이미 닉네임 설정되어 있으면 거부
    if (await hasNickname()) {
      throw Exception('닉네임은 한 번만 설정할 수 있어요');
    }

    // Firestore에 사용자 문서 생성
    await _db.collection('users').doc(uid).set({
      'nickname': trimmed,
      'joinedAt': FieldValue.serverTimestamp(),
      'avatarColor': _randomColor(),
    });

    // 로컬 캐시
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', trimmed);
  }

  /// 아바타 컬러 가져오기
  Future<String> getAvatarColor() async {
    final uid = this.uid;
    if (uid == null) return '#6B7684';
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['avatarColor'] as String? ?? '#6B7684';
  }

  /// 랜덤 아바타 컬러 생성
  String _randomColor() {
    final colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A',
      '#98D8C8', '#F7DC6F', '#F97316', '#03C75A',
      '#8B5CF6', '#EC4899', '#14B8A6', '#3B82F6',
    ];
    return colors[Random().nextInt(colors.length)];
  }
}
