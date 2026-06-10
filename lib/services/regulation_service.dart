import 'dart:convert';
import 'package:flutter/services.dart';

class RegulationService {
  Map<String, dynamic>? _regulationData;
  Map<String, dynamic>? _meta;

  Future<void> loadRegulations() async {
    try {
      final String response = await rootBundle.loadString('assets/fish_rules.json');
      final decoded = json.decode(response) as Map<String, dynamic>;

      // _meta는 분리해서 보관
      _meta = decoded['_meta'] as Map<String, dynamic>?;
      _regulationData = Map.from(decoded)..remove('_meta');

      print("✅ 금어기 JSON 로드 성공! (${_regulationData!.length}종)");
      if (_meta != null) {
        print("   버전: ${_meta!['version']}, 갱신일: ${_meta!['last_updated']}");
      }
    } catch (e) {
      print("❌ 금어기 데이터 로드 실패: $e");
    }
  }

  /// 어종명 (한국어)으로 규정 정보 조회
  Map<String, dynamic>? getRegulationInfo(String koreanName) {
    if (_regulationData == null) return null;
    return _regulationData![koreanName] as Map<String, dynamic>?;
  }

  /// 데이터 출처 및 면책 문구
  String get sourceInfo => _meta?['source'] ?? '';
  String get disclaimer => _meta?['disclaimer'] ?? '';
  String get version => _meta?['version'] ?? '';
  String get lastUpdated => _meta?['last_updated'] ?? '';

  /// 규정 정보가 "확인 필요" 상태인지 체크 (불완전 정보)
  bool isRegulationIncomplete(Map<String, dynamic> reg) {
    final fishingBan = reg['금어기']?.toString() ?? '';
    final minSize = reg['금지체장']?.toString() ?? '';
    return fishingBan.contains('확인 필요') || minSize.contains('확인 필요');
  }
}