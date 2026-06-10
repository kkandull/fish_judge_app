// 본인이 차단한 사용자 UID 목록 관리.
// SharedPreferences에 로컬 저장.
// 차단된 사용자의 게시글은 목록에서 안 보이게 필터링.

import 'package:shared_preferences/shared_preferences.dart';

class BlockService {
  static const String _key = 'blocked_uids';
  
  /// 사용자 차단
  static Future<void> blockUser(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_key) ?? [];
    if (!blocked.contains(uid)) {
      blocked.add(uid);
      await prefs.setStringList(_key, blocked);
    }
  }
  
  /// 차단 해제
  static Future<void> unblockUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_key) ?? [];
    blocked.remove(uid);
    await prefs.setStringList(_key, blocked);
  }
  
  /// 차단된 UID 목록
  static Future<List<String>> getBlockedUids() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }
  
  /// 특정 사용자 차단 여부
  static Future<bool> isBlocked(String uid) async {
    final blocked = await getBlockedUids();
    return blocked.contains(uid);
  }
  
  /// 모든 차단 해제 (개발/테스트용)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
