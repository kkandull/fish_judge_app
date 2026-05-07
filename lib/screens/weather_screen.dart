import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class WeatherScreenData {
  final String temperature;
  final String windSpeed;
  final String windDirection;
  final double windAngle;
  final String waveHeight;
  final String waterTemp;
  final String recommendedFish;
  final bool isOffline;
  final DateTime updateTime;

  WeatherScreenData({
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
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  Future<WeatherScreenData>? _weatherDataFuture;
  StreamSubscription<Position>? _positionStream;

  bool _isDangerZone = false;
  String _currentDangerPlace = "";
  bool _isDismissedManually = false;
  bool _isRefreshing = false;

  late AnimationController _blinkController;
  late AnimationController _floatController;

  // ✅ 공공데이터포털 서비스 키 (기상청 + 국립해양조사원 공통)
  final String apiKey =
      'cdd83e12a3b04b72dfbc96976e346cd1625e1bd75790c0886e5b4a00a3dd8be3';

  final List<Map<String, dynamic>> dangerPoints = [
    {'name': '해운대 마린시티', 'lat': 35.1587, 'lng': 129.1601},
    {'name': '오륙도 방파제', 'lat': 35.1001, 'lng': 129.1226},
    {'name': '영도 신방파제', 'lat': 35.0867, 'lng': 129.0778},
    {'name': '영도 국립해양박물관 갯바위', 'lat': 35.0789, 'lng': 129.0801},
    {'name': '암남공원 방파제', 'lat': 35.0634, 'lng': 129.0208},
    {'name': '감천항 동방파제', 'lat': 35.0511, 'lng': 129.0089},
    {'name': '기장 학리방파제', 'lat': 35.2580, 'lng': 129.2464},
    {'name': '가덕도 대항방파제', 'lat': 35.0122, 'lng': 128.8273},
  ];

  @override
  void initState() {
    super.initState();
    _weatherDataFuture = _fetchAllData();
    _startLocationTracking();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _blinkController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          bool foundDanger = false;
          String placeName = "";

          for (var point in dangerPoints) {
            double distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              point['lat'],
              point['lng'],
            );
            if (distance <= 100) {
              foundDanger = true;
              placeName = point['name'];
              break;
            }
          }

          if (foundDanger) {
            if (_currentDangerPlace != placeName) {
              setState(() {
                _isDangerZone = true;
                _currentDangerPlace = placeName;
                _isDismissedManually = false;
              });
            }
          } else {
            if (_isDangerZone || _currentDangerPlace.isNotEmpty) {
              setState(() {
                _isDangerZone = false;
                _currentDangerPlace = "";
                _isDismissedManually = false;
              });
            }
          }
        });
  }

  String _formatDate(DateTime date) {
    return "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
  }

  String _getWindDirectionStr(double degree) {
    const directions = [
      "북",
      "북북동",
      "북동",
      "동북동",
      "동",
      "동남동",
      "남동",
      "남남동",
      "남",
      "남남서",
      "남서",
      "서남서",
      "서",
      "서북서",
      "북서",
      "북북서",
      "북",
    ];
    int index = ((degree + 11.25) % 360 / 22.5).floor();
    return "${directions[index]}풍";
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<WeatherScreenData> _fetchAllData() async {
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
      // ── 기상청 초단기실황 API (변경 없음) ──────────────────
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

      // ── 국립해양조사원 조위관측소 실측 수온 API ──────────────
      final waterResult = await _fetchWaterTemp(now);
      if (waterResult != null) {
        water = waterResult;
        await prefs.setString('cached_water', water);
      } else {
        water = prefs.getString('cached_water') ?? defaultWater;
        debugPrint('수온 API 실패, 캐시 또는 기본값($water) 사용');
      }
    } else {
      // ── 오프라인: 로컬 캐시 사용 ────────────────────────────
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

    final fish = _getRecommendedFish(updateTime.month, water);

    return WeatherScreenData(
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

  // ── 기상청 초단기실황 (변경 없음) ────────────────────────────
  Future<Map<String, String>?> _fetchKmaData(DateTime now) async {
    try {
      final kmaTime = now.minute < 45
          ? now.subtract(const Duration(hours: 1))
          : now;
      final baseDate = _formatDate(kmaTime);
      final baseTime = "${kmaTime.hour.toString().padLeft(2, '0')}00";

      final url =
          'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst'
          '?serviceKey=$apiKey&pageNo=1&numOfRows=100&dataType=JSON'
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
            result['windDir'] = _getWindDirectionStr(deg);
            break;
        }
      }
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('기상청 예외: $e');
      return null;
    }
  }

  // ── ✅ 국립해양조사원 조위관측소 실측 수온 (신규 교체) ───────────
  // Base URL: apis.data.go.kr/1192136/surveyWaterTemp
  // API: /GetSurveyWaterTempApiService
  // 부산 조위관측소 코드: DT_0019
  Future<String?> _fetchWaterTemp(DateTime now) async {
    const obsCodes = [
      'DT_0019', // 부산항 (1순위)
      'DT_0020', // 거제도 (2순위)
      'DT_0063', // 가덕도 (3순위)
      'DT_0021', // 통영   (4순위)
    ];

    for (final obsCode in obsCodes) {
      for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
        try {
          final targetDate = _formatDate(
            now.subtract(Duration(days: dayOffset)),
          );

          final url =
              'https://apis.data.go.kr/1192136/surveyWaterTemp/GetSurveyWaterTempApiService'
              '?serviceKey=$apiKey'
              '&pageNo=1'
              '&numOfRows=24'
              '&dataType=JSON'
              '&obsCode=$obsCode'
              '&date=$targetDate';

          debugPrint('수온 API 요청 ($obsCode, offset=$dayOffset)');

          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));

          if (res.statusCode != 200) continue;

          final body = utf8.decode(res.bodyBytes);

          // ✅ XML이어도 resultCode 00이면 파싱 시도
          if (body.trim().startsWith('<')) {
            // resultCode 40 = 관측소 점검 중 → 다음 관측소로
            if (body.contains('<resultCode>40</resultCode>')) {
              debugPrint('수온 관측소 점검 중 ($obsCode) → 다음으로');
              break;
            }

            // resultCode 00 = 성공이지만 XML로 왔을 때 → XML 파싱
            if (body.contains('<resultCode>00</resultCode>')) {
              final wtMatch = RegExp(r'<wtem>([\d.]+)</wtem>').allMatches(body);
              if (wtMatch.isNotEmpty) {
                final vals = wtMatch
                    .map((m) => double.tryParse(m.group(1) ?? ''))
                    .whereType<double>()
                    .toList();
                if (vals.isNotEmpty) {
                  final avg = vals.reduce((a, b) => a + b) / vals.length;
                  debugPrint('✅ 수온 성공 XML파싱 ($obsCode): ${avg.toStringAsFixed(1)}°C');
                  return '${avg.toStringAsFixed(1)}°C';
                }
              }
            }

            debugPrint('수온 알 수 없는 XML 에러 ($obsCode)');
            break;
          }

          // JSON 응답 처리
          final resJson = jsonDecode(body);
          final items =
              resJson['response']?['body']?['items']?['item'] as List?;

          if (items != null && items.isNotEmpty) {
            final latest = items.last;
            final val = latest['wtem'] ?? latest['wtemp'] ?? latest['water_temp'];
            if (val != null) {
              final wtValue = double.parse(val.toString());
              debugPrint('✅ 수온 성공 JSON ($obsCode): $wtValue°C');
              return '${wtValue.toStringAsFixed(1)}°C';
            }
          }
        } catch (e) {
          debugPrint('수온 예외 ($obsCode, offset=$dayOffset): $e');
        }
      }
    }
    return null;
  }

  String _getRecommendedFish(int month, String waterStr) {
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

  Future<void> _handleRefresh() async {
    final newData = await _fetchAllData();
    if (mounted) {
      setState(() {
        _weatherDataFuture = Future.value(newData);
      });
    }
  }

  Future<void> _handleButtonRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final newData = await _fetchAllData();
      if (mounted) {
        setState(() {
          _weatherDataFuture = Future.value(newData);
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherScreenData>(
      future: _weatherDataFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final data =
            snapshot.data ??
            WeatherScreenData(
              temperature: '18.5°C',
              windSpeed: '2.3m/s',
              windDirection: '북서풍',
              windAngle: 315.0,
              waveHeight: '0.5m 내외',
              waterTemp: '16.2°C',
              recommendedFish: '데이터를 불러오는 중입니다...',
              isOffline: false,
              updateTime: DateTime.now(),
            );

        final amPm = data.updateTime.hour < 12 ? '오전' : '오후';
        final hour = data.updateTime.hour > 12
            ? data.updateTime.hour - 12
            : (data.updateTime.hour == 0 ? 12 : data.updateTime.hour);
        final timeStr =
            "${data.updateTime.year}.${data.updateTime.month.toString().padLeft(2, '0')}.${data.updateTime.day.toString().padLeft(2, '0')} $amPm $hour:${data.updateTime.minute.toString().padLeft(2, '0')}";

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFC),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '현재 바다 상황',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  '업데이트: $timeStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            actions: [
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.blueAccent,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.blueAccent,
                      ),
                tooltip: '날씨/수온 새로고침',
                onPressed: _isRefreshing ? null : _handleButtonRefresh,
              ),
              IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.redAccent),
                tooltip: 'UI 테스트용 강제 경고창',
                onPressed: () {
                  setState(() {
                    _isDangerZone = true;
                    _currentDangerPlace = "오륙도 방파제 (테스트)";
                    _isDismissedManually = false;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFF1976D2),
                backgroundColor: Colors.white,
                child: Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: AnimatedOpacity(
                      opacity: (isLoading || _isRefreshing) ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (data.isOffline)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "인터넷 연결이 끊겨 로컬 데이터를 표시합니다.",
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildRecommendedFishSection(
                            data.recommendedFish,
                            data.updateTime.month,
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: const [
                              Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '실시간 해양 데이터 (부산 앞바다)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildInfoCard(
                                "기온",
                                data.temperature,
                                null,
                                Icons.thermostat,
                                const Color(0xFFFF8A65),
                              ),
                              const SizedBox(width: 14),
                              _buildInfoCard(
                                "풍속",
                                data.windSpeed,
                                data.windDirection,
                                Icons.air,
                                const Color(0xFF4DB6AC),
                                windAngle: data.windAngle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildInfoCard(
                                "파고",
                                data.waveHeight,
                                null,
                                Icons.waves,
                                const Color(0xFF7986CB),
                              ),
                              const SizedBox(width: 14),
                              _buildInfoCard(
                                "수온",
                                data.waterTemp,
                                null,
                                Icons.water_drop,
                                const Color(0xFF64B5F6),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isDangerZone && !_isDismissedManually)
                GestureDetector(
                  onTap: () => setState(() => _isDismissedManually = true),
                  child: Container(
                    color: Colors.red.withOpacity(0.2),
                    child: Center(
                      child: FadeTransition(
                        opacity: _blinkController,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(
                            vertical: 30,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "위험!\n현재 [$_currentDangerPlace]\n추락 위험 지역입니다!",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "(화면을 터치하면 닫힙니다)",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendedFishSection(String text, int month) {
    final List<TextSpan> spans = [];
    final exp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final m in exp.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD54F),
            fontSize: 16,
          ),
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    String seasonIcon = "❄️";
    if (month >= 3 && month <= 5)
      seasonIcon = "🌸";
    else if (month >= 6 && month <= 8)
      seasonIcon = "☀️";
    else if (month >= 9 && month <= 11)
      seasonIcon = "🍁";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF243046),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -6 * _floatController.value),
              child: child,
            ),
            child: Text(seasonIcon, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$month월 바다 추천",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    children: spans,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    String? subtitle,
    IconData icon,
    Color color, {
    double windAngle = 0.0,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: title == "풍속"
                  ? Transform.rotate(
                      angle: (windAngle + 180) * 3.1415926535 / 180,
                      child: Icon(
                        Icons.navigation_rounded,
                        color: color,
                        size: 24,
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF868E96),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF212529),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
