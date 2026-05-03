import 'dart:convert';
import 'package:flutter/services.dart';

class RegulationService {
  Map<String, dynamic>? _regulationData;

  // 앱 화면이 켜질 때 JSON 파일을 메모리로 싹 다 불러옵니다.
  Future<void> loadRegulations() async {
    try {
      // pubspec.yaml에 등록한 경로와 정확히 일치해야 합니다!
      final String response = await rootBundle.loadString('assets/fish_rules.json');
      _regulationData = json.decode(response);
      print("✅ 금어기 JSON 데이터 로드 성공!");
    } catch (e) {
      print("❌ 금어기 데이터 로드 실패: $e");
    }
  }

  // 화면 코드에서 어종 이름을 넘겨주면, 그에 맞는 규정(Map)을 뱉어줍니다.
  Map<String, dynamic>? getRegulationInfo(String fishName) {
    // 아직 로드가 안 되었거나, 해당 어종 데이터가 없으면 null 반환
    if (_regulationData == null || !_regulationData!.containsKey(fishName)) {
      return null;
    }
    return _regulationData![fishName];
  }
}