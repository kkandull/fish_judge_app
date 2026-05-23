import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 날씨/수온 데이터 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeatherData {
  final String temperature;      // 예: "23.1°C"
  final String windSpeed;        // 예: "2.5m/s"
  final String windDirection;    // 예: "북서풍"
  final double windAngle;        // 0~359 (도)
  final String waveHeight;       // 예: "0.5m 내외"
  final String waterTemp;        // 예: "16.4°C"
  final String recommendedFish;  // 마크다운 형식 ("**감성돔**과 ...")
  final bool isOffline;          // 네트워크 끊김 여부
  final DateTime updateTime;     // 갱신 시각

  const WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.windAngle,
    required this.waveHeight,
    required this.waterTemp,
    required this.recommendedFish,
    required this.isOffline,
    required this.updateTime,
  });

  /// 기본값(첫 로딩 중에 보여줄 placeholder)
  factory WeatherData.placeholder() => WeatherData(
        temperature: '--°C',
        windSpeed: '--m/s',
        windDirection: '--',
        windAngle: 0.0,
        waveHeight: '--',
        waterTemp: '--°C',
        recommendedFish: '데이터를 불러오는 중입니다...',
        isOffline: false,
        updateTime: DateTime.now(),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 WeatherService — 싱글톤 패턴 + 인메모리 캐시
//
// 사용법:
//   final data = await WeatherService.instance.fetchAll();
//   final data = await WeatherService.instance.fetchAll(forceRefresh: true);
//
// 5분 이내 재호출 시 캐시 반환 → 홈/날씨화면 동시 진입해도 API 1번만 호출
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  /// 공공데이터포털 서비스 키 (기상청 + 국립해양조사원 공통)
  static const String _apiKey =
      'cdd83e12a3b04b72dfbc96976e346cd1625e1bd75790c0886e5b4a00a3dd8be3';

  /// 인메모리 캐시 (앱 세션 동안만 유효)
  WeatherData? _cached;
  DateTime? _cachedAt;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// 진행 중인 fetch 작업 (동시 호출 방지)
  Future<WeatherData>? _inFlight;

  // ───────────────────────────────────────────────────────────
  // 메인 API
  // ───────────────────────────────────────────────────────────

  /// 모든 날씨 데이터를 가져옴. 5분 이내 캐시 있으면 즉시 반환.
  Future<WeatherData> fetchAll({bool forceRefresh = false}) async {
    // 1. 캐시 확인
    if (!forceRefresh && _cached != null && _cachedAt != null) {
      final age = DateTime.now().difference(_cachedAt!);
      if (age < _cacheValidity) {
        return _cached!;
      }
    }

    // 2. 동시 호출 시 같은 Future 공유
    if (_inFlight != null) return _inFlight!;

    _inFlight = _fetchAllInternal();
    try {
      final data = await _inFlight!;
      _cached = data;
      _cachedAt = DateTime.now();
      return data;
    } finally {
      _inFlight = null;
    }
  }

  /// 현재 캐시된 데이터 (없으면 null) — 비동기 대기 없이 즉시 사용
  WeatherData? get cachedData => _cached;

  /// 캐시 무효화
  void invalidateCache() {
    _cached = null;
    _cachedAt = null;
  }

  // ───────────────────────────────────────────────────────────
  // 내부 구현
  // ───────────────────────────────────────────────────────────

  Future<WeatherData> _fetchAllInternal() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    const String defaultTemp = '18.5°C';
    const String defaultWind = '2.3m/s';
    const String defaultWindDir = '북서풍';
    const double defaultWindDeg = 315.0;
    const String defaultWave = '0.5m 내외';
    const String defaultWater = '16.2°C';

    final bool isOnline = await _checkInternet();

    String temp = defaultTemp;
    String wind = defaultWind;
    String windDir = defaultWindDir;
    double windDeg = defaultWindDeg;
    String wave = defaultWave;
    String water = defaultWater;
    DateTime updateTime = now;

    if (isOnline) {
      // 기상청 초단기실황
      final kmaResult = await _fetchKmaData(now);
      if (kmaResult != null) {
        temp = kmaResult['temp'] ?? defaultTemp;
        wind = kmaResult['wind'] ?? defaultWind;
        windDir = kmaResult['windDir'] ?? defaultWindDir;
        windDeg = double.tryParse(kmaResult['windDeg'] ?? '') ?? defaultWindDeg;

        await prefs.setString('cached_temp', temp);
        await prefs.setString('cached_wind', wind);
        await prefs.setString('cached_windDir', windDir);
        await prefs.setDouble('cached_windDeg', windDeg);
        await prefs.setString('cached_time', now.toIso8601String());
        updateTime = now;
      } else {
        temp = prefs.getString('cached_temp') ?? defaultTemp;
        wind = prefs.getString('cached_wind') ?? defaultWind;
        windDir = prefs.getString('cached_windDir') ?? defaultWindDir;
        windDeg = prefs.getDouble('cached_windDeg') ?? defaultWindDeg;
        final cachedTimeStr = prefs.getString('cached_time');
        updateTime = cachedTimeStr != null
            ? (DateTime.tryParse(cachedTimeStr) ?? now)
            : now;
      }

      // 국립해양조사원 수온
      final waterResult = await _fetchWaterTemp(now);
      if (waterResult != null) {
        water = waterResult;
        await prefs.setString('cached_water', water);
      } else {
        water = prefs.getString('cached_water') ?? defaultWater;
      }
    } else {
      // 오프라인: 캐시
      temp = prefs.getString('cached_temp') ?? defaultTemp;
      wind = prefs.getString('cached_wind') ?? defaultWind;
      windDir = prefs.getString('cached_windDir') ?? defaultWindDir;
      windDeg = prefs.getDouble('cached_windDeg') ?? defaultWindDeg;
      water = prefs.getString('cached_water') ?? defaultWater;
      final cachedTimeStr = prefs.getString('cached_time');
      updateTime = cachedTimeStr != null
          ? (DateTime.tryParse(cachedTimeStr) ?? now)
          : now;
    }

    final fish = getRecommendedFish(updateTime.month, water);

    return WeatherData(
      temperature: temp,
      windSpeed: wind,
      windDirection: windDir,
      windAngle: windDeg,
      waveHeight: wave,
      waterTemp: water,
      recommendedFish: fish,
      isOffline: !isOnline,
      updateTime: updateTime,
    );
  }

  // ───────────────────────────────────────────────────────────
  // 헬퍼
  // ───────────────────────────────────────────────────────────

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
  }

  String getWindDirectionStr(double degree) {
    const directions = [
      "북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동",
      "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서", "북",
    ];
    int index = ((degree + 11.25) % 360 / 22.5).floor();
    return "${directions[index]}풍";
  }

  // ── 기상청 초단기실황 ───────────────────────────────────
  Future<Map<String, String>?> _fetchKmaData(DateTime now) async {
    try {
      final kmaTime =
          now.minute < 45 ? now.subtract(const Duration(hours: 1)) : now;
      final baseDate = _formatDate(kmaTime);
      final baseTime = "${kmaTime.hour.toString().padLeft(2, '0')}00";

      final url =
          'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst'
          '?serviceKey=$_apiKey&pageNo=1&numOfRows=100&dataType=JSON'
          '&base_date=$baseDate&base_time=$baseTime&nx=98&ny=73';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return null;

      final body = utf8.decode(res.bodyBytes);
      if (body.trim().startsWith('<')) return null;

      final json = jsonDecode(body);
      if (json['response']?['header']?['resultCode'] != '00') return null;

      final items = json['response']['body']['items']['item'] as List;
      final result = <String, String>{};

      for (final item in items) {
        switch (item['category']) {
          case 'T1H':
            result['temp'] = '${item['obsrValue']}°C';
            break;
          case 'WSD':
            result['wind'] = '${item['obsrValue']}m/s';
            break;
          case 'VEC':
            final deg = double.parse(item['obsrValue'].toString());
            result['windDeg'] = deg.toString();
            result['windDir'] = getWindDirectionStr(deg);
            break;
        }
      }
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('기상청 예외: $e');
      return null;
    }
  }

  // ── 국립해양조사원 조위관측소 실측 수온 ─────────────────
  Future<String?> _fetchWaterTemp(DateTime now) async {
    const obsCodes = [
      'DT_0019', // 부산항
      'DT_0020', // 거제도
      'DT_0063', // 가덕도
      'DT_0021', // 통영
    ];

    for (final obsCode in obsCodes) {
      for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
        try {
          final targetDate =
              _formatDate(now.subtract(Duration(days: dayOffset)));

          final url =
              'https://apis.data.go.kr/1192136/surveyWaterTemp/GetSurveyWaterTempApiService'
              '?serviceKey=$_apiKey'
              '&pageNo=1&numOfRows=24&dataType=JSON'
              '&obsCode=$obsCode&date=$targetDate';

          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));

          if (res.statusCode != 200) continue;

          final body = utf8.decode(res.bodyBytes);

          if (body.trim().startsWith('<')) {
            if (body.contains('<resultCode>40</resultCode>')) break;

            if (body.contains('<resultCode>00</resultCode>')) {
              final matches =
                  RegExp(r'<wtem>([\d.]+)</wtem>').allMatches(body);
              if (matches.isNotEmpty) {
                final vals = matches
                    .map((m) => double.tryParse(m.group(1) ?? ''))
                    .whereType<double>()
                    .toList();
                if (vals.isNotEmpty) {
                  final avg = vals.reduce((a, b) => a + b) / vals.length;
                  return '${avg.toStringAsFixed(1)}°C';
                }
              }
            }
            break;
          }

          final resJson = jsonDecode(body);
          final items =
              resJson['response']?['body']?['items']?['item'] as List?;

          if (items != null && items.isNotEmpty) {
            final latest = items.last;
            final val =
                latest['wtem'] ?? latest['wtemp'] ?? latest['water_temp'];
            if (val != null) {
              final wtValue = double.parse(val.toString());
              return '${wtValue.toStringAsFixed(1)}°C';
            }
          }
        } catch (e) {
          debugPrint('수온 예외 ($obsCode, $dayOffset): $e');
        }
      }
    }
    return null;
  }

  // ── 추천 어종 결정 ───────────────────────────────────────
  String getRecommendedFish(int month, String waterStr) {
    final waterTemp =
        double.tryParse(waterStr.replaceAll('°C', '').trim()) ?? 16.2;

    if (month >= 3 && month <= 5) {
      return waterTemp >= 15.0
          ? "수온이 올라 **벵에돔**과 **참돔** 낚시를 추천해요!"
          : "아직 바다가 차가워요. **볼락**과 **감성돔**이 제격이에요!";
    } else if (month >= 6 && month <= 8) {
      return waterTemp >= 22.0
          ? "여름 바다의 제왕! **무늬오징어**와 **돌돔**을 노려보세요."
          : "활성도가 좋습니다! **참돔**과 **농어**를 잡기 딱 좋아요.";
    } else if (month >= 9 && month <= 11) {
      return waterTemp >= 18.0
          ? "가을 낚시의 꽃, **감성돔**과 **쭈꾸미** 낚시 어떠세요?"
          : "수온이 떨어지고 있어요. 바닥층 **우럭**과 **쥐노래미**를 추천해요.";
    } else {
      return "겨울 바다의 묘미, **호루기**와 **방어**가 제철입니다!";
    }
  }
}