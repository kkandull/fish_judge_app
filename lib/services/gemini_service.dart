// lib/services/gemini_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../models/unified_catch_record.dart';

class GeminiService {
  GeminiService._();
  static final instance = GeminiService._();

  GenerativeModel? _model;

  Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 12),
      ));
      await rc.fetchAndActivate();

      final apiKey = rc.getString('gemini_api_key');
      debugPrint('[Gemini] API 키 길이: ${apiKey.length}자');

      if (apiKey.isEmpty) {
        debugPrint('[Gemini] ⚠️ API 키 없음');
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 800,
          temperature: 0.3,
        ),
      );
      debugPrint('[Gemini] ✅ 초기화 완료');
    } catch (e) {
      debugPrint('[Gemini] ❌ 초기화 실패: $e');
    }
  }

  bool get isAvailable => _model != null;

  // ── 홈 화면 낚시 코치 멘트 ──────────────────────────
  Future<String?> getFishingAdvice({
    required String region,
    required double waterTempC,
    required double windSpeedMs,
    required double waveHeightM,
    required int month,
  }) async {
    if (!isAvailable) return null;

    final windDesc = windSpeedMs <= 2 ? '바람 없음'
        : windSpeedMs <= 4 ? '약한 바람'
        : windSpeedMs <= 7 ? '보통 바람'
        : '강풍';
    final waveDesc = waveHeightM <= 0.3 ? '매우 잔잔'
        : waveHeightM <= 0.8 ? '잔잔'
        : waveHeightM <= 1.5 ? '약간 높음'
        : '높음';

    // Few-shot 방식: 예시를 먼저 보여주고 같은 형식으로 출력하도록 유도
    final prompt = '''아래는 한국 바다낚시 추천 예시입니다.

[예시1]
조건: 부산, 6월, 수온 19°C, 바람 없음, 파고 잔잔
출력: 잔잔한 바다에 수온도 딱 좋아요! 크릴로 갯바위 감성돔을 노려보세요 🎣

[예시2]
조건: 통영, 4월, 수온 14°C, 약한 바람, 파고 잔잔
출력: 봄 시즌 시작! 지그헤드로 볼락 마릿수 도전해보세요

[예시3]
조건: 여수, 8월, 수온 24°C, 보통 바람, 파고 약간 높음
출력: 파고 있으니 방파제 안쪽에서 갈치 야간낚시 추천해요

---
이제 아래 조건으로 위 예시와 똑같은 형식의 한국어 추천 문장을 딱 한 줄만 출력하세요.
영어는 절대 사용하지 마세요. 반드시 완전한 문장으로 끝내세요.

조건: $region, ${month}월, 수온 ${waterTempC.toStringAsFixed(1)}°C, $windDesc, 파고 $waveDesc
출력:''';

    try {
      debugPrint('[Gemini] 홈 코치 요청 중...');
      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 10));

      var text = response.text?.trim() ?? '';
      debugPrint('[Gemini] 홈 코치 응답: $text');

      if (text.isEmpty) return null;

      // "출력:" 접두사 혹시 붙어있으면 제거
      if (text.startsWith('출력:')) text = text.substring(3).trim();
      text = text.replaceAll('"', '').replaceAll("'", '');

      // 영어 비율 체크 — 영어가 30% 이상이면 null 반환(폴백)
      final engCount = RegExp(r'[a-zA-Z]').allMatches(text).length;
      if (text.isNotEmpty && engCount / text.length > 0.3) {
        debugPrint('[Gemini] 영어 비율 높음 → 폴백');
        return null;
      }

      return text;
    } catch (e) {
      debugPrint('[Gemini] 홈 코치 실패: $e');
      return null; // 홈은 폴백으로 하드코딩 텍스트 표시
    }
  }

  // ── 판독 후 어종별 조언 ────────────────────────────
  Future<List<String>?> getFishingTipsAfterCapture({
    required String fishName,
    required double waterTempC,
    required double waveHeightM,
    required int month,
  }) async {
    if (!isAvailable) return null;

    final prompt = '''아래는 낚시 팁 작성 예시입니다.

[예시 — 감성돔, 5월, 수온 17°C]
크릴새우를 바늘에 꿰어 갯바위 하단 3m를 공략하세요
조류 소통이 좋은 곶부리 지점이 감성돔 명당이에요
해 질 무렵 30분이 감성돔 입질 황금 타이밍입니다

---
아래 조건에 맞는 팁 3가지를 예시와 똑같이 작성하세요.
규칙: 한국어만 사용, 각 줄 15~30자 완전한 문장, 줄바꿈으로만 구분, 번호/기호 없음.

어종: $fishName
조건: ${month}월, 수온 ${waterTempC.toStringAsFixed(1)}°C, 파고 ${waveHeightM.toStringAsFixed(1)}m''';

    try {
      debugPrint('[Gemini] 판독 조언 요청 중...');
      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 10));

      var text = response.text?.trim() ?? '';
      debugPrint('[Gemini] 판독 조언 응답: $text');
      if (text.isEmpty) return null;

      final lines = text
          .split('\n')
          .map((l) => l.trim())
          // 번호 접두사 제거 (1. 2. ① 등)
          .map((l) => l.replaceFirst(RegExp(r'^[\d①②③\-\*\.]+\s*'), ''))
          .where((l) => l.isNotEmpty && l.length >= 8)
          .take(3)
          .toList();

      if (lines.isEmpty) return null;

      // 영어 비율 체크
      for (final line in lines) {
        final eng = RegExp(r'[a-zA-Z]').allMatches(line).length;
        if (line.isNotEmpty && eng / line.length > 0.3) {
          debugPrint('[Gemini] 판독 조언 영어 비율 높음 → 폴백');
          return null;
        }
      }

      return lines;
    } catch (e) {
      debugPrint('[Gemini] 판독 조언 실패: $e');
      return null;
    }
  }
  // ── 낚시 패턴 분석 ────────────────────────────────
  Future<String?> getPatternInsight({
    required List<UnifiedCatchRecord> records,
    double? currentWaterTemp,
    int? currentMonth,
  }) async {
    if (!isAvailable) return null;
    if (records.isEmpty) return null;

    final recent = records.toList()
      ..sort((a, b) => b.catchTime.compareTo(a.catchTime));
    final top = recent.take(20).toList();

    final buffer = StringBuffer();
    for (final r in top) {
      final hour = r.catchTime.hour;
      final timeDesc = hour < 6 ? '새벽'
          : hour < 10 ? '오전'
          : hour < 14 ? '낮'
          : hour < 18 ? '오후'
          : '저녁';
      final loc = r.locationName ?? '위치 미상';
      final size = r.lengthCm != null
          ? ' ${r.lengthCm!.toStringAsFixed(0)}cm' : '';
      buffer.writeln('${r.catchTime.month}월 $timeDesc ${r.fishName}$size ($loc)');
    }
    final recordLines = buffer.toString().trim();

    final weatherCtx = currentWaterTemp != null
        ? '현재 수온: ${currentWaterTemp.toStringAsFixed(1)}°C, ${currentMonth ?? DateTime.now().month}월'
        : '${currentMonth ?? DateTime.now().month}월';

    // 영어 출력 방지: 한국어 예시를 함께 제공
    final prompt =
        '다음은 나의 최근 낚시 조과 기록이야:\n'
        '$recordLines\n\n'
        '현재 조건: $weatherCtx\n\n'
        '위 기록을 보고 한국어 존댓말로 딱 3문장만 써줘. '
        '첫째 문장: 주로 잡는 어종과 시간대 패턴. '
        '둘째 문장: 현재 수온과 연결한 오늘 추천. '
        '셋째 문장: 응원 멘트. '
        '반드시 한국어만 쓰고, 문장을 끝까지 완성해줘. '
        '예시: "주로 새벽에 볼락을 잘 잡으시네요! 현재 수온이 그때와 비슷해서 오늘도 기대해볼 만해요. 이번 주말 새벽 출조 응원할게요 🎣"';

    try {
      debugPrint('[Gemini] 패턴 분석 요청 중... (${top.length}개 기록)');
      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));

      final text = response.text?.trim();
      debugPrint('[Gemini] 패턴 분석 응답: $text');
      if (text == null || text.isEmpty) return null;

      final engCount = RegExp(r'[a-zA-Z]').allMatches(text).length;
      if (text.isNotEmpty && engCount / text.length > 0.25) {
        debugPrint('[Gemini] 패턴 분석 영어 비율 높음 → 폴백');
        return null;
      }
      return text;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('quota') || errStr.contains('RESOURCE_EXHAUSTED')) {
        debugPrint('[Gemini] 쿼터 초과');
        return '__quota__';
      }
      if (errStr.contains('503') || errStr.contains('UNAVAILABLE')) {
        debugPrint('[Gemini] 서버 과부하 — 잠시 후 재시도');
        return '__quota__'; // 동일 안내 메시지 재사용
      }
      debugPrint('[Gemini] 패턴 분석 실패: $e');
      return null;
    }
  }

}