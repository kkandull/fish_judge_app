// lib/services/weather_service.dart
// v3 — 승인된 KHOA API 실제 엔드포인트로 교체
//  ✅ /1192136/surveyWaterTemp  — 수온 (실측)
//  ✅ /1192136/dtRecent          — 조위관측소 최신 (기온/풍속/파고)
//  ✅ /1192136/tideFcstHghLw     — 조석예보 (만조/간조)
//  ✅ /1360000/WthrWrnInfoService — 기상특보 (기존 키)
//  ✅ /1360000/VilageFcstInfoService_2.0 — 기상청 단기예보 (기존 키)

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_alert_service.dart';

class ApiConfig {
  // 기상청 API (기존 — 기상 단기예보 + 기상특보)
  static const String kmaApiKey =
      'cdd83e12a3b04b72dfbc96976e346cd1625e1bd75790c0886e5b4a00a3dd8be3';

  // ⭐ 해양조사원 신규 승인 키
  // 샘플 URL에서 확인된 키 2개 — 둘 중 실제 내 계정 키를 여기에 입력
  // 공공데이터포털 로그인 → 마이페이지 → 일반 인증키(Encoding) 확인
  static const String khoaApiKey =
      'cdd83e12a3b04b72dfbc96976e346cd1625e1bd75790c0886e5b4a00a3dd8be3';
  // ↑ 같은 계정의 키면 동일. 다른 계정이면 승인된 키로 교체 필요.

  static bool get hasKey => kmaApiKey.isNotEmpty;
  static bool get hasKhoaKey => khoaApiKey.isNotEmpty;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 지역 정보 (전국 주요 낚시 지역)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class FishingRegion {
  final String id;
  final String name;
  final String province;
  final int nx;
  final int ny;
  final String khoaCode;
  final double lat;
  final double lng;
  final String alertStnId;  // 기상특보 지역코드

  const FishingRegion({
    required this.id,
    required this.name,
    required this.province,
    required this.nx,
    required this.ny,
    required this.khoaCode,
    required this.lat,
    required this.lng,
    this.alertStnId = '26',  // 기본: 부산
  });
}

const List<FishingRegion> kFishingRegions = [
  // 부산
  FishingRegion(id:'busan',     name:'부산 앞바다', province:'부산', nx:98,  ny:76,  khoaCode:'DT_0005', lat:35.18, lng:129.07, alertStnId:'26'),
  // 경남
  FishingRegion(id:'geoje',     name:'거제도',      province:'경남', nx:91,  ny:68,  khoaCode:'DT_0029', lat:34.87, lng:128.62, alertStnId:'48'),
  FishingRegion(id:'tongyeong', name:'통영',        province:'경남', nx:87,  ny:68,  khoaCode:'DT_0014', lat:34.85, lng:128.43, alertStnId:'48'),
  FishingRegion(id:'namhae',    name:'남해',        province:'경남', nx:82,  ny:68,  khoaCode:'DT_0061', lat:34.84, lng:127.89, alertStnId:'48'),
  // 전남
  FishingRegion(id:'yeosu',     name:'여수',   province:'전남', nx:73,  ny:66,  khoaCode:'DT_0016', lat:34.74, lng:127.73, alertStnId:'46'),
  FishingRegion(id:'wando',     name:'완도',   province:'전남', nx:63,  ny:67,  khoaCode:'DT_0027', lat:34.40, lng:126.70, alertStnId:'46'),
  FishingRegion(id:'mokpo',     name:'목포',   province:'전남', nx:54,  ny:73,  khoaCode:'DT_0007', lat:34.79, lng:126.38, alertStnId:'46'),
  // 제주
  FishingRegion(id:'jeju',      name:'제주',   province:'제주', nx:53,  ny:38,  khoaCode:'DT_0004', lat:33.51, lng:126.52, alertStnId:'50'),
  FishingRegion(id:'seogwipo',  name:'서귀포', province:'제주', nx:52,  ny:33,  khoaCode:'DT_0010', lat:33.24, lng:126.56, alertStnId:'50'),
  // 경북
  FishingRegion(id:'pohang',    name:'포항',   province:'경북', nx:102, ny:84,  khoaCode:'DT_0091', lat:36.02, lng:129.37, alertStnId:'47'),
  FishingRegion(id:'ulleung',   name:'울릉도', province:'경북', nx:127, ny:84,  khoaCode:'DT_0013', lat:37.49, lng:130.91, alertStnId:'47'),
  // 강원
  FishingRegion(id:'gangneung', name:'강릉',   province:'강원', nx:92,  ny:131, khoaCode:'SO_0733', lat:37.75, lng:128.88, alertStnId:'42'),
  FishingRegion(id:'sokcho',    name:'속초',   province:'강원', nx:87,  ny:141, khoaCode:'DT_0012', lat:38.21, lng:128.59, alertStnId:'42'),
  // 인천
  FishingRegion(id:'incheon',   name:'인천',   province:'인천', nx:54,  ny:124, khoaCode:'DT_0001', lat:37.45, lng:126.70, alertStnId:'28'),
  // 충남/서해
  FishingRegion(id:'boryeong',  name:'보령',   province:'충남', nx:54,  ny:100, khoaCode:'DT_0025', lat:36.33, lng:126.49, alertStnId:'44'),
];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeatherData {
  final FishingRegion region;
  final double airTempC;
  final double waterTempC;
  final double windSpeedMs;
  final String windDirection;
  final double waveHeightM;
  final int rainProbability;
  final String skyCondition;
  final CurrentInfo? current;
  final FogInfo? fog;
  final TideInfo tide;
  final SunMoonInfo sunMoon;
  final FishingScore fishingScore;
  final List<WeatherAlert> alerts;
  final DateTime updatedAt;
  final bool isUsingDummy;

  WeatherData({
    required this.region,
    required this.airTempC,
    required this.waterTempC,
    required this.windSpeedMs,
    required this.windDirection,
    required this.waveHeightM,
    required this.rainProbability,
    required this.skyCondition,
    this.current,
    this.fog,
    required this.tide,
    required this.sunMoon,
    required this.fishingScore,
    required this.alerts,
    required this.updatedAt,
    this.isUsingDummy = false,
  });

  bool get hasActiveAlerts => alerts.any((a) => a.isCurrentlyActive);
}

class CurrentInfo {
  final double speedCmPerSec;
  final double directionDeg;
  CurrentInfo({required this.speedCmPerSec, required this.directionDeg});

  String get directionLabel {
    const d = ['북','북동','동','남동','남','남서','서','북서'];
    return d[((directionDeg + 22.5) / 45).floor() % 8];
  }
  String get strengthLabel {
    if (speedCmPerSec < 10) return '약함';
    if (speedCmPerSec < 30) return '보통';
    if (speedCmPerSec < 50) return '강함';
    return '매우 강함';
  }
  int get fishingBonus {
    if (speedCmPerSec >= 15 && speedCmPerSec <= 40) return 10;
    if (speedCmPerSec < 5) return -5;
    if (speedCmPerSec > 60) return -10;
    return 0;
  }
}

class FogInfo {
  final double visibilityM;
  FogInfo({required this.visibilityM});
  bool get isFoggy => visibilityM < 1000;
  bool get isDangerous => visibilityM < 500;
  String get label {
    if (visibilityM < 200) return '짙은 안개';
    if (visibilityM < 500) return '안개';
    if (visibilityM < 1000) return '옅은 안개';
    if (visibilityM < 4000) return '연무';
    return '맑음';
  }
}

class TideInfo {
  final List<TideEvent> events;
  final String mulTtae;
  final TideEvent? nextEvent;
  TideInfo({required this.events, required this.mulTtae, this.nextEvent});
}

class TideEvent {
  final DateTime time;
  final bool isHighTide;
  final double levelCm;
  TideEvent({required this.time, required this.isHighTide, required this.levelCm});
  String get label => isHighTide ? '만조' : '간조';
}

class SunMoonInfo {
  final DateTime sunrise;
  final DateTime sunset;
  final double moonPhase;
  final String moonName;
  SunMoonInfo({required this.sunrise, required this.sunset, required this.moonPhase, required this.moonName});
}

class FishingScore {
  final int score;
  final String grade;
  final List<String> reasons;
  FishingScore({required this.score, required this.grade, required this.reasons});

  String get colorHex {
    if (score >= 80) return '0xFF03C75A';
    if (score >= 60) return '0xFF1976D2';
    if (score >= 40) return '0xFFFFA726';
    return '0xFFE53935';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WeatherService
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeatherService {
  static final WeatherService instance = WeatherService._();
  WeatherService._();

  // 지역별 캐시 (regionId → data)
  final Map<String, WeatherData> _cache = {};
  final Map<String, DateTime> _cachedAt = {};
  // 진행 중인 fetch (중복 호출 방지)
  final Map<String, Future<WeatherData>> _inFlight = {};

  // 현재 선택 지역 (기본: 부산)
  FishingRegion _selectedRegion = kFishingRegions.first;
  FishingRegion get selectedRegion => _selectedRegion;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_region_id') ?? 'busan';
    _selectedRegion = kFishingRegions.firstWhere(
      (r) => r.id == savedId,
      orElse: () => kFishingRegions.first,
    );
  }

  Future<void> selectRegion(FishingRegion region) async {
    _selectedRegion = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_region_id', region.id);
    // ⭐ 캐시 없으면 백그라운드에서 미리 로드 (UI 블로킹 없음)
    if (!_cache.containsKey(region.id)) {
      fetchForRegion(region).catchError((_) => null);
    }
  }

  /// 현재 선택 지역 데이터 가져오기
  Future<WeatherData> fetch({bool forceRefresh = false}) async {
    return fetchForRegion(_selectedRegion, forceRefresh: forceRefresh);
  }

  /// 특정 지역 데이터 가져오기
  Future<WeatherData> fetchForRegion(FishingRegion region, {bool forceRefresh = false}) async {
    // 캐시 히트
    final cached = _cache[region.id];
    final cachedTime = _cachedAt[region.id];
    if (!forceRefresh &&
        cached != null &&
        cachedTime != null &&
        DateTime.now().difference(cachedTime).inMinutes < 60) {
      return cached;
    }

    // 이미 같은 지역 요청 진행 중이면 그 Future 공유 (중복 API 호출 방지)
    if (_inFlight.containsKey(region.id)) {
      return _inFlight[region.id]!;
    }

    final future = _doFetch(region, forceRefresh: forceRefresh);
    _inFlight[region.id] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(region.id);
    }
  }

  Future<WeatherData> _doFetch(FishingRegion region, {bool forceRefresh = false}) async {
    try {
      // ⭐ 6개 API 전부 동시에 병렬 호출 — 가장 느린 것 기준으로 완료
      final results = await Future.wait([
        _fetchKmaForecast(region).catchError((e) {          // [0] 기상청
          debugPrint('❌ [날씨] KMA 호출 실패: $e');
          return _dummyKma();
        }),
        _fetchKhoaObs(region).catchError((e) {              // [1] 조위관측
          debugPrint('❌ [날씨] KHOA 예외: $e');
          return _realisticFallbackObs(region);
        }),
        _fetchTideForecast(region).catchError((e) {         // [2] 조석
          debugPrint('❌ [날씨] 조석 호출 실패: $e');
          return _dummyTide();
        }),
        WeatherAlertService.instance.fetchActiveAlerts(     // [3] 기상특보
          apiKey: ApiConfig.kmaApiKey,
          stnId: region.alertStnId,
          forceRefresh: forceRefresh,
        ).catchError((_) => <WeatherAlert>[]),
        _fetchWaterTemp(region).catchError((_) => null),    // [4] 수온 실측
        _fetchSunMoon(region).catchError((_) =>             // [5] 천문연구원
            _calcSunMoon(DateTime.now(), region.lat, region.lng)),
      ]);

      final kma       = results[0] as Map<String, dynamic>;
      final khoa      = results[1] as Map<String, dynamic>;
      final tide      = results[2] as TideInfo;
      final alerts    = results[3] as List<WeatherAlert>;
      final surveyTemp = results[4] as double?;
      final sunMoon   = results[5] as SunMoonInfo;

      final airTemp   = _firstDouble([khoa['airTemp'], kma['airTemp'], 18.0])!;
      final windSpeed = _firstDouble([khoa['windSpeed'], kma['windSpeed'], 2.5])!;
      final waterTemp = _firstDouble([surveyTemp, khoa['waterTemp'], 16.0])!;
      final windDir   = khoa['windDir'] as String? ?? kma['windDir'] as String? ?? '동북동풍';
      final waveH     = _firstDouble([khoa['waveHeight'], 0.5])!;
      final rainProb  = kma['rainProb'] as int? ?? 20;
      final sky       = kma['sky'] as String? ?? '맑음';
      final score = _calcScore(
        windMs: windSpeed, waveM: waveH, rainProb: rainProb,
        waterTemp: waterTemp, tide: tide, alerts: alerts,
      );

      final data = WeatherData(
        region: region,
        airTempC: airTemp,
        waterTempC: waterTemp,
        windSpeedMs: windSpeed,
        windDirection: windDir,
        waveHeightM: waveH,
        rainProbability: rainProb,
        skyCondition: sky,
        tide: tide,
        sunMoon: sunMoon,
        fishingScore: score,
        alerts: alerts,
        updatedAt: DateTime.now(),
        isUsingDummy: !ApiConfig.hasKey,
      );

      _cache[region.id] = data;
      _cachedAt[region.id] = DateTime.now();
      debugPrint('📊 [날씨] 최종 결과 (${region.name}): 기온=${data.airTempC.toStringAsFixed(1)}°C, 수온=${data.waterTempC.toStringAsFixed(1)}°C, 풍속=${data.windSpeedMs.toStringAsFixed(1)}m/s, 파고=${data.waveHeightM.toStringAsFixed(1)}m, 적합도=${data.fishingScore.score}점 (${data.isUsingDummy ? "⚠️더미" : "✅실제"})');
      return data;
    } catch (e) {
      debugPrint('fetch 실패(${ region.name}): $e');
      return _cache[region.id] ?? _dummyData(region);
    }
  }

  // ── 기상청 단기예보 ──────────────────────────────────
  Future<Map<String, dynamic>> _fetchKmaForecast(FishingRegion r) async {
    if (!ApiConfig.hasKey) return _dummyKma();
    final now = DateTime.now();
    final base = _nearestBaseTime(now);
    final url = Uri.https('apis.data.go.kr',
        '/1360000/VilageFcstInfoService_2.0/getVilageFcst', {
      'serviceKey': ApiConfig.kmaApiKey,
      'numOfRows': '300', 'pageNo': '1', 'dataType': 'JSON',
      'base_date': _ymd(base), 'base_time': '${base.hour.toString().padLeft(2,'0')}00',
      'nx': '${r.nx}', 'ny': '${r.ny}',
    });
    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('KMA ${res.statusCode}');
    final j = jsonDecode(res.body);
    if (j['response']?['header']?['resultCode'] != '00') throw Exception('KMA error');
    final items = j['response']?['body']?['items']?['item'] as List? ?? [];
    final _kmaResult = _parseKma(items, now);
    debugPrint('✅ [날씨] KMA 실제 데이터: 기온=${_kmaResult["airTemp"]}°C, 풍속=${_kmaResult["windSpeed"]}m/s');
    return _kmaResult;
  }

  Map<String, dynamic> _parseKma(List items, DateTime now) {
    final dateStr = _ymd(now);
    final curH = now.hour;
    double tmp=18, wsd=2.5, vec=0; int pop=20, sky=1, pty=0;
    String? sunrise, sunset;
    int best = 999;

    for (final it in items) {
      if (it['fcstDate'] != dateStr) continue;
      final cat = (it['category'] ?? '').toString();
      final val = (it['fcstValue'] ?? '').toString();

      // ⭐ SR=일출, SS=일몰 — 시간 무관하게 파싱 (하루에 하나)
      if (cat == 'SR' && sunrise == null) {
        sunrise = val; // 'HHMM' 형식 예: '0531'
      }
      if (cat == 'SS' && sunset == null) {
        sunset = val;
      }

      // 기온/풍속 등은 현재 시각과 가장 가까운 값
      final fh = int.tryParse(val.length >= 2 ? (it['fcstTime']?.toString().substring(0,2) ?? '0') : '0') ?? 0;
      final d = (fh - curH).abs();
      if (d > best) continue;
      best = d;
      final v = double.tryParse(val) ?? 0;
      switch (cat) {
        case 'TMP': tmp = v; break;
        case 'WSD': wsd = v; break;
        case 'VEC': vec = v; break;
        case 'POP': pop = v.toInt(); break;
        case 'SKY': sky = v.toInt(); break;
        case 'PTY': pty = v.toInt(); break;
      }
    }

    if (sunrise != null) debugPrint('✅ [날씨] KMA 일출: $sunrise, 일몰: $sunset');
    return {
      'airTemp': tmp, 'windSpeed': wsd, 'windDir': _vec2dir(vec),
      'rainProb': pop, 'sky': _skyStr(sky, pty),
      'sunrise': sunrise,
      'sunset':  sunset,
    };
  }

  DateTime _nearestBaseTime(DateTime now) {
    const h = [2,5,8,11,14,17,20,23];
    for (int i = h.length-1; i >= 0; i--) {
      final c = DateTime(now.year, now.month, now.day, h[i]);
      if (now.isAfter(c.add(const Duration(minutes: 10)))) return c;
    }
    return DateTime(now.year, now.month, now.day-1, 23);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ 조위관측소 최신 관측 (풍속/파고/기온 포함)
  //    신규 엔드포인트: /1192136/dtRecent/GetDTRecentApiService
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Map<String, dynamic>> _fetchKhoaObs(FishingRegion r) async {
    if (!ApiConfig.hasKhoaKey) return _realisticFallbackObs(r);
    final url = Uri.https('apis.data.go.kr',
        '/1192136/dtRecent/GetDTRecentApiService', {
      'serviceKey': ApiConfig.khoaApiKey,
      'obsCode':    r.khoaCode,
      'reqDate':    _todayYmd(),
      'min':        '60',
    });
    debugPrint('🌊 [날씨] 조위관측 호출');
    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return _realisticFallbackObs(r);
    try {
      final body = res.body;
      debugPrint('🌊 원문: ${body.substring(0, body.length < 300 ? body.length : 300)}');
      final items = _parseXmlItems(body);
      if (items.isEmpty) return _realisticFallbackObs(r);
      final latest = items.last;
      debugPrint('   필드: ${latest.keys.join(", ")}');

      // ⭐ 실제 필드명 (로그에서 확인됨)
      // wtem=수온, wspd=풍속, wndrct=풍향(도), artmp=기온
      final waterTemp  = double.tryParse(latest['wtem']  ?? '');
      final airTemp    = double.tryParse(latest['artmp'] ?? '');
      final windSpeed  = double.tryParse(latest['wspd']  ?? '');
      final windDirRaw = double.tryParse(latest['wndrct'] ?? '');

      debugPrint('✅ [날씨] KHOA 실제: 수온=${waterTemp}°C 풍속=${windSpeed}m/s 기온=${airTemp}°C');
      return {
        'waterTemp':  waterTemp,
        'airTemp':    airTemp,
        'windSpeed':  windSpeed,
        'windDir':    windDirRaw != null ? _vec2dir(windDirRaw) : null,
        'waveHeight': 0.5,   // 조위관측소엔 파고 없음
      };
    } catch (e) {
      debugPrint('❌ [날씨] 조위관측 파싱 실패: $e');
      return _realisticFallbackObs(r);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ 수온 실측 (별도 API — 더 정확한 수온)
  //    신규 엔드포인트: /1192136/surveyWaterTemp/GetSurveyWaterTempApiService
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<double?> _fetchWaterTemp(FishingRegion r) async {
    if (!ApiConfig.hasKhoaKey) return null;
    final url = Uri.https('apis.data.go.kr',
        '/1192136/surveyWaterTemp/GetSurveyWaterTempApiService', {
      'serviceKey': ApiConfig.khoaApiKey,
      'type':       'json',
      'obsCode':    r.khoaCode,
      'reqDate':    _todayYmd(),
      'min':        '60',
      'pageNo':     '1',
      'numOfRows':  '5',
    });

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final body = res.body;
      // XML/JSON 모두 처리
      List<Map<String, String>> items = _parseXmlItems(body);
      if (items.isEmpty) {
        try {
          final j = jsonDecode(body);
          final raw = j['result']?['data'] ?? j['response']?['body']?['items']?['item'];
          if (raw is List) items = raw.map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))).toList();
        } catch (_) {}
      }
      if (items.isEmpty) return null;
      final latest = items.last;
      // 실제 필드명: wtem (조위관측소와 동일 패턴)
      final wt = _d(latest['wtem'] ?? latest['wTemp'] ?? latest['waterTemp']);
      if (wt != null) debugPrint('🌡️ [날씨] 수온 실측: $wt°C');
      return wt;
    } catch (e) {
      debugPrint('⚠️ [날씨] 수온 실측 실패: $e');
      return null;
    }
  }

  /// fallback: 月별 평균 수온 (KHOA 통계 기반)
  Map<String, dynamic> _realisticFallbackObs(FishingRegion r) {
    const temps = [0.0, 12.5, 11.8, 12.5, 14.2, 17.1, 20.8, 24.6, 26.3, 24.5, 21.2, 17.8, 14.1];
    final m = DateTime.now().month;
    final adj = (35.18 - r.lat) * 0.3;
    final waterTemp = (temps[m] + adj).clamp(8.0, 30.0);
    debugPrint('📍 [날씨] 수온 fallback ($m월/${r.name}): ${waterTemp.toStringAsFixed(1)}°C');
    return {
      'waterTemp': waterTemp,
      'airTemp': null, 'windSpeed': null, 'windDir': null,
      'waveHeight': 0.5,
    };
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ 조석예보 (만조/간조)
  //    신규 엔드포인트: /1192136/tideFcstHghLw/GetTideFcstHghLwApiService
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<TideInfo> _fetchTideForecast(FishingRegion r) async {
    if (!ApiConfig.hasKhoaKey) return _dummyTide();
    final url = Uri.https('apis.data.go.kr',
        '/1192136/tideFcstHghLw/GetTideFcstHghLwApiService', {
      'serviceKey': ApiConfig.khoaApiKey,
      'obsCode':    r.khoaCode,
    });
    debugPrint('🌊 [날씨] 조석예보 호출');
    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) { debugPrint('⚠️ 조석 ${res.statusCode}'); return _dummyTide(); }
    try {
      final body = res.body;
      debugPrint('🌊 조석 원문: ${body.substring(0, body.length < 400 ? body.length : 400)}');
      final items = _parseXmlItems(body);
      if (items.isEmpty) return _dummyTide();
      final now = DateTime.now();
      final events = <TideEvent>[];
      for (final it in items) {
        try {
          // ⭐ 실제 필드명 (로그에서 확인됨):
          // predcDt=예측시간, predcTdlvVl=조위(cm), extrSe=1만조/2간조/3만조/4간조
          final timeStr = (it['predcDt'] ?? it['fcstDatetime'] ?? it['tph_time'] ?? '').toString();
          if (timeStr.isEmpty) continue;

          final t = DateTime.parse(timeStr.replaceAll(' ', 'T'));
          if (t.day != now.day) continue;

          // extrSe: 1,3 = 만조(고조), 2,4 = 간조(저조)
          final extrSe = int.tryParse(it['extrSe'] ?? '0') ?? 0;
          final isHigh = extrSe == 1 || extrSe == 3;

          final level = _d(it['predcTdlvVl'] ?? it['tph_level'] ?? it['level']) ?? 0.0;
          events.add(TideEvent(time: t, isHighTide: isHigh, levelCm: level));
          debugPrint('✅ 조석: ${isHigh ? "만조" : "간조"} ${t.hour}:${t.minute.toString().padLeft(2, "0")} ${level.toStringAsFixed(0)}cm (extrSe=$extrSe)');
        } catch (e) {
          debugPrint('⚠️ 조석항목 파싱: $e / $it');
        }
      }
      final next = events.where((e) => e.time.isAfter(now)).firstOrNull;
      debugPrint('✅ [날씨] 조석 ${events.length}건 파싱 완료, 다음: ${next?.label} ${next?.time.hour}:${next?.time.minute.toString().padLeft(2,"0")}');
      return TideInfo(events: events, mulTtae: _mulTtae(now), nextEvent: next);
    } catch (e) {
      debugPrint('❌ [날씨] 조석 파싱 실패: $e');
      return _dummyTide();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ 한국천문연구원 출몰시각 API
  //    getLCRiseSetInfo — 위치(위도/경도) 기반 일출/일몰/월출/월몰
  //    응답: sunrise(HHMMSS), sunset(HHMMSS), moonrise, moonset
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<SunMoonInfo> _fetchSunMoon(FishingRegion r) async {
    final today = DateTime.now();
    final locdate = _ymd(today); // YYYYMMDD

    final url = Uri.http(
      'apis.data.go.kr',
      '/B090041/openapi/service/RiseSetInfoService/getLCRiseSetInfo',
      {
        'ServiceKey': ApiConfig.kmaApiKey,
        'locdate':    locdate,
        'longitude':  r.lng.toStringAsFixed(7),
        'latitude':   r.lat.toStringAsFixed(7),
        'dnYn':       'Y',   // 10진수 좌표
      },
    );

    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('천문연구원 ${res.statusCode}');

    final body = res.body;
    debugPrint('☀️ [날씨] 천문연구원 응답: ${body.substring(0, body.length < 200 ? body.length : 200)}');

    // XML 파싱 — _parseXmlItems 재사용
    final items = _parseXmlItems(body);
    if (items.isEmpty) throw Exception('천문연구원 빈 응답');

    final item = items.first;
    debugPrint('☀️ 출몰 필드: ${item.keys.join(", ")}');

    // sunrise/sunset: 'HHMMSS' 형식 (예: '053127')
    final todayDate = DateTime(today.year, today.month, today.day);

    DateTime parseTime(String? raw) {
      if (raw == null || raw.length < 4) return todayDate;
      try {
        final h = int.parse(raw.substring(0, 2));
        final m = int.parse(raw.substring(2, 4));
        return todayDate.add(Duration(hours: h, minutes: m));
      } catch (_) {
        return todayDate;
      }
    }

    final sunrise   = parseTime(item['sunrise']);
    final sunset    = parseTime(item['sunset']);
    final moonrise  = parseTime(item['moonrise']);
    final moonset   = parseTime(item['moonset']);

    debugPrint('☀️ 일출: ${item['sunrise']} → ${sunrise.hour}:${sunrise.minute.toString().padLeft(2,"0")}');
    debugPrint('🌙 일몰: ${item['sunset']} → ${sunset.hour}:${sunset.minute.toString().padLeft(2,"0")}');
    debugPrint('🌙 월출: ${item['moonrise']}, 월몰: ${item['moonset']}');

    // 월령 계산
    final daysSince = todayDate.difference(DateTime(2000, 1, 6)).inDays;
    final phaseDays = daysSince % 29.530588853;
    final moonPhase = phaseDays / 29.530588853;
    const moonNames = ['신월','초승달','상현달','차오르는 달','보름달','기우는 달','하현달','그믐달'];
    final mIdx = ((moonPhase * 8) % 8).floor();

    return SunMoonInfo(
      sunrise:   sunrise,
      sunset:    sunset,
      moonPhase: moonPhase,
      moonName:  moonNames[mIdx],
    );
  }

  // ── 일출/일몰/월령 ────────────────────────────────
  // 천문연구원 API 실패 시 fallback 계산식
  // KMA 단기예보 SR/SS 카테고리 우선, 없으면 계산식
  SunMoonInfo _calcSunMoon(DateTime date, double lat, double lng,
      {String? kmaSunrise, String? kmaSunset}) {
    final today = DateTime(date.year, date.month, date.day);

    DateTime sunrise, sunset;

    // ⭐ KMA 일출 (SR 카테고리) — 'HHMM' 형식
    if (kmaSunrise != null && kmaSunrise.length == 4) {
      try {
        final h = int.parse(kmaSunrise.substring(0, 2));
        final m = int.parse(kmaSunrise.substring(2, 4));
        sunrise = today.add(Duration(hours: h, minutes: m));
        debugPrint('✅ [날씨] KMA 일출 적용: ${h.toString().padLeft(2,"0")}:${m.toString().padLeft(2,"0")}');
      } catch (_) {
        sunrise = _calcSunriseApprox(today, lat);
      }
    } else {
      sunrise = _calcSunriseApprox(today, lat);
    }

    // ⭐ KMA 일몰 (SS 카테고리)
    if (kmaSunset != null && kmaSunset.length == 4) {
      try {
        final h = int.parse(kmaSunset.substring(0, 2));
        final m = int.parse(kmaSunset.substring(2, 4));
        sunset = today.add(Duration(hours: h, minutes: m));
        debugPrint('✅ [날씨] KMA 일몰 적용: ${h.toString().padLeft(2,"0")}:${m.toString().padLeft(2,"0")}');
      } catch (_) {
        sunset = _calcSunsetApprox(today, lat);
      }
    } else {
      sunset = _calcSunsetApprox(today, lat);
    }

    // 월령 계산
    final daysSince = today.difference(DateTime(2000, 1, 6)).inDays;
    final phaseDays = daysSince % 29.530588853;
    final moonPhase = phaseDays / 29.530588853;
    const moonNames = ['신월','초승달','상현달','차오르는 달','보름달','기우는 달','하현달','그믐달'];
    final mIdx = ((moonPhase * 8) % 8).floor();

    return SunMoonInfo(
      sunrise:   sunrise,
      sunset:    sunset,
      moonPhase: moonPhase,
      moonName:  moonNames[mIdx],
    );
  }

  DateTime _calcSunriseApprox(DateTime today, double lat) {
    final doy = today.difference(DateTime(today.year, 1, 1)).inDays;
    final ph = (doy - 80) / 365.25 * 2 * math.pi;
    final latOff = ((lat - 35) * 2).round();
    final srMin = 7 * 60 + 30 + (-90 * math.sin(ph)).round() - latOff;
    return today.add(Duration(minutes: srMin));
  }

  DateTime _calcSunsetApprox(DateTime today, double lat) {
    final doy = today.difference(DateTime(today.year, 1, 1)).inDays;
    final ph = (doy - 80) / 365.25 * 2 * math.pi;
    final latOff = ((lat - 35) * 2).round();
    final ssMin = 17 * 60 + 30 + (90 * math.sin(ph)).round() - latOff;
    return today.add(Duration(minutes: ssMin));
  }

  // ── 낚시 점수 ─────────────────────────────────────
  FishingScore _calcScore({
    required double windMs, required double waveM, required int rainProb,
    required double waterTemp, required TideInfo tide, required List<WeatherAlert> alerts,
    CurrentInfo? current, FogInfo? fog,
  }) {
    int score = 100;
    final reasons = <String>[];

    // 기상특보 (최우선 — 대폭 감점)
    for (final a in alerts) {
      if (!a.isCurrentlyActive) continue;
      score -= (a.type.fishingPenalty * a.level.multiplier).toInt();
      reasons.insert(0, '${a.title} 발효 중 - 출조 자제');
    }

    // ⭐ 풍속 — 기준 현실화
    if (windMs >= 10)      { score -= 50; reasons.add('강풍 (${windMs.toStringAsFixed(1)}m/s) - 위험'); }
    else if (windMs >= 7)  { score -= 30; reasons.add('강한 바람 (${windMs.toStringAsFixed(1)}m/s)'); }
    else if (windMs >= 5)  { score -= 15; reasons.add('다소 강한 바람 (${windMs.toStringAsFixed(1)}m/s)'); }
    else if (windMs >= 3)  { score -= 5;  reasons.add('약간의 바람 (${windMs.toStringAsFixed(1)}m/s)'); }
    else                   { reasons.add('바람 없음 (${windMs.toStringAsFixed(1)}m/s) - 최적'); }

    // ⭐ 파고 — 기준 현실화
    if (waveM >= 2.0)      { score -= 40; reasons.add('높은 파고 (${waveM.toStringAsFixed(1)}m) - 갯바위 위험'); }
    else if (waveM >= 1.5) { score -= 25; reasons.add('다소 높은 파고 (${waveM.toStringAsFixed(1)}m)'); }
    else if (waveM >= 1.0) { score -= 10; reasons.add('파고 ${waveM.toStringAsFixed(1)}m - 주의'); }
    else if (waveM >= 0.5) { score -= 3;  reasons.add('잔잔한 바다 (${waveM.toStringAsFixed(1)}m)'); }
    else                   { reasons.add('매우 잔잔 (${waveM.toStringAsFixed(1)}m) - 최적'); }

    // ⭐ 강수 확률 — 기준 현실화
    if (rainProb >= 70)      { score -= 30; reasons.add('비 올 확률 높음 ($rainProb%)'); }
    else if (rainProb >= 50) { score -= 15; reasons.add('비 가능성 ($rainProb%)'); }
    else if (rainProb >= 30) { score -= 5;  reasons.add('약간의 강수 가능 ($rainProb%)'); }

    // 수온
    if (waterTemp < 8 || waterTemp > 28) {
      score -= 20; reasons.add('수온 부적합 (${waterTemp.toStringAsFixed(1)}°C)');
    } else if (waterTemp >= 14 && waterTemp <= 22) {
      score += 5; reasons.add('수온 ${waterTemp.toStringAsFixed(1)}°C - 최적');
    } else if (waterTemp < 12) {
      score -= 10; reasons.add('수온 낮음 (${waterTemp.toStringAsFixed(1)}°C)');
    }

    // 물때
    if (tide.mulTtae.contains('사리'))      { score += 10; reasons.add('사리 - 조류 활발'); }
    else if (tide.mulTtae.contains('조금')) { score -= 5;  reasons.add('조금 - 조류 약함'); }

    // 만조/간조 타이밍
    if (tide.nextEvent != null) {
      final m = tide.nextEvent!.time.difference(DateTime.now()).inMinutes;
      if (m > 0 && m < 60) { score += 10; reasons.add('${m}분 후 ${tide.nextEvent!.label} - 황금 타이밍'); }
      else if (m >= 60 && m < 120) { score += 5; reasons.add('${m}분 후 ${tide.nextEvent!.label}'); }
    }

    if (current != null) {
      score += current.fishingBonus;
      if (current.fishingBonus > 0) reasons.add('조류 ${current.strengthLabel} - 입질 활발');
    }
    if (fog != null && fog.isDangerous) { score -= 30; reasons.add('짙은 안개 - 출항 위험'); }

    score = score.clamp(0, 100);
    final grade = score >= 80 ? '최고' : score >= 60 ? '좋음' : score >= 40 ? '보통' : score >= 20 ? '주의' : '위험';
    return FishingScore(score: score, grade: grade, reasons: reasons);
  }

  // ── 유틸 ───────────────────────────────────────────
  String _ymd(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
  String _todayYmd() => _ymd(DateTime.now());
  double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
  double? _firstDouble(List<dynamic?> list) {
    for (final v in list) { if (v != null) return (v as num).toDouble(); }
    return null;
  }
  List _extractList(dynamic j) {
    if (j['result']?['data'] is List) return j['result']['data'] as List;
    final item = j['response']?['body']?['items']?['item'];
    if (item is List) return item;
    if (item is Map) return [item];
    return [];
  }

  // ⭐ XML → List<Map> 파싱 유틸
  // KHOA API는 XML로 응답 — 태그 값을 Map으로 변환
  List<Map<String, String>> _parseXmlItems(String xml) {
    final result = <Map<String, String>>[];
    // <item> 또는 <row> 블록 추출
    final blockRe = RegExp(r'<(?:item|row)>([\s\S]*?)<\/(?:item|row)>');
    for (final block in blockRe.allMatches(xml)) {
      final item = <String, String>{};
      final inner = block.group(1)!;
      // ⭐ Dart는 backreference(\1) 미지원 → 직접 필드명 추출
      // 각 필드를 독립 정규식으로 추출: <태그>값</태그>
      // 여는 태그 목록을 먼저 수집하고 값 추출
      final openRe = RegExp(r'<([A-Za-z][A-Za-z0-9_]*)>');
      for (final open in openRe.allMatches(inner)) {
        final tag = open.group(1)!;
        final closeTag = '<\/$tag>';
        final valueStart = open.end;
        final closeIdx = inner.indexOf(closeTag, valueStart);
        if (closeIdx < 0) continue;
        final value = inner.substring(valueStart, closeIdx).trim();
        // 값 안에 '<'가 없어야 단순 텍스트 노드
        if (!value.contains('<')) item[tag] = value;
      }
      if (item.isNotEmpty) result.add(item);
    }
    return result;
  }

  String _vec2dir(double v) {
    const d = ['북','북북동','북동','동북동','동','동남동','남동','남남동',
                '남','남남서','남서','서남서','서','서북서','북서','북북서'];
    return '${d[((v+11.25)/22.5).floor()%16]}풍';
  }
  String _skyStr(int sky, int pty) {
    if (pty==1) return '비'; if (pty==2) return '비/눈';
    if (pty==3) return '눈'; if (pty==4) return '소나기';
    return sky==1?'맑음':sky==3?'구름많음':'흐림';
  }
  String _mulTtae(DateTime d) {
    final n = ((d.difference(DateTime(d.year,1,1)).inDays*12.37/365)%15).floor()+1;
    if (n==7||n==8) return '$n물 (조금)';
    if (n==14||n==15) return '$n물 (사리)';
    return '$n물';
  }

  // ── 더미 ───────────────────────────────────────────
  // ⚠️ 이 함수가 호출되면 API 실패 중인 것
  Map<String, dynamic> _dummyKma() {
    debugPrint('⚠️ [날씨] KMA 더미 사용 — API 실패 또는 키 없음');
    return {
      'airTemp': 18.0,      // 고정값 (랜덤 제거)
      'windSpeed': 3.0,
      'windDir': '동북동풍', 'rainProb': 20, 'sky': '구름많음',
    };
  }
  Map<String, dynamic> _dummyKhoaObs() {
    debugPrint('⚠️ [날씨] KHOA 더미 사용 — API 실패 또는 키 없음');
    return {
      'waterTemp': 17.0,    // 고정값 (랜덤 제거)
      'airTemp': null, 'windSpeed': null, 'windDir': null,
      'waveHeight': 0.5,
    };
  }
  TideInfo _dummyTide() {
    final now = DateTime.now();
    final t = DateTime(now.year,now.month,now.day);
    final events = [
      TideEvent(time: t.add(const Duration(hours:3,minutes:15)), isHighTide:true,  levelCm:145),
      TideEvent(time: t.add(const Duration(hours:9,minutes:30)), isHighTide:false, levelCm:32),
      TideEvent(time: t.add(const Duration(hours:15,minutes:45)),isHighTide:true,  levelCm:152),
      TideEvent(time: t.add(const Duration(hours:22,minutes:10)),isHighTide:false, levelCm:28),
    ];
    final next = events.where((e)=>e.time.isAfter(now)).firstOrNull;
    return TideInfo(events:events, mulTtae:_mulTtae(now), nextEvent:next);
  }
  WeatherData _dummyData(FishingRegion r) {
    final kma=_dummyKma(); final khoa=_dummyKhoaObs(); final tide=_dummyTide();
    return WeatherData(
      region:r, airTempC:kma['airTemp'], waterTempC:khoa['waterTemp'],
      windSpeedMs:kma['windSpeed'], windDirection:kma['windDir'],
      waveHeightM:khoa['waveHeight'], rainProbability:kma['rainProb'],
      skyCondition:kma['sky'], tide:tide,
      sunMoon:_calcSunMoon(DateTime.now(),r.lat,r.lng),
      fishingScore:_calcScore(windMs:kma['windSpeed'],waveM:khoa['waveHeight'],
        rainProb:kma['rainProb'],waterTemp:khoa['waterTemp'],tide:tide,alerts:[]),
      alerts:[], updatedAt:DateTime.now(), isUsingDummy:true,
    );
  }
}