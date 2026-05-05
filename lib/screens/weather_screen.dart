import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class WeatherScreenData {
  final String temperature;
  final String windSpeed;
  final String windDirection; // 💡 풍향 텍스트 (예: 북서풍)
  final double windAngle;     // 💡 화살표 회전을 위한 각도
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

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  Future<WeatherScreenData>? _weatherDataFuture;
  StreamSubscription<Position>? _positionStream; 
  
  bool _isDangerZone = false; 
  String _currentDangerPlace = ""; 
  bool _isDismissedManually = false; 

  late AnimationController _blinkController;
  late AnimationController _floatController; 

  final String apiKey = 'ad7fabf94911978da64e3ef42abbf6f9097211711390790b71b9a32fc7af34e7';

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
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      bool foundDanger = false;
      String placeName = "";

      for (var point in dangerPoints) {
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, point['lat'], point['lng']
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

  // 💡 풍향 각도(0~360)를 한글 16방위로 변환하는 함수
  String _getWindDirectionStr(double degree) {
    List<String> directions = ["북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동", "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서", "북"];
    int index = ((degree + 11.25) % 360 / 22.5).floor();
    return "${directions[index]}풍";
  }

  Future<WeatherScreenData> _fetchAllData() async {
    String temp = '18.5°C';
    String wind = '2.3m/s';
    String wave = '0.5m 내외'; 
    String water = '16.2°C';
    String fish = '';
    
    // 풍향 변수 초기화
    String windDir = "풍향 미상";
    double windDeg = 0.0;
    
    bool offlineMode = false; 
    DateTime now = DateTime.now();

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) offlineMode = true;
    } on SocketException catch (_) {
      offlineMode = true; 
    }

    if (!offlineMode) {
      try {
        DateTime kmaTime = now.minute < 45 ? now.subtract(const Duration(hours: 1)) : now;
        String baseDate = _formatDate(kmaTime);
        String baseTime = "${kmaTime.hour.toString().padLeft(2, '0')}00";

        String kmaUrl = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst?serviceKey=$apiKey&pageNo=1&numOfRows=100&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=98&ny=76';
        final kmaRes = await http.get(Uri.parse(kmaUrl)).timeout(const Duration(seconds: 3));
        
        if (kmaRes.statusCode == 200) {
          var res = jsonDecode(utf8.decode(kmaRes.bodyBytes));
          if (res['response'] != null && res['response']['header']['resultCode'] == '00') {
            var items = res['response']['body']['items']['item'] as List;
            for (var item in items) {
              if (item['category'] == 'T1H') temp = '${item['obsrValue']}°C';
              if (item['category'] == 'WSD') wind = '${item['obsrValue']}m/s';
              if (item['category'] == 'VEC') { // 💡 풍향 파싱 추가!
                windDeg = double.parse(item['obsrValue'].toString());
                windDir = _getWindDirectionStr(windDeg);
              }
            }
          }
        }
      } catch (e) {
        debugPrint("기상청 API 수신 실패");
      }

      try {
        List<DateTime> datesToTry = [now, now.subtract(const Duration(days: 1))];
        bool waterSuccess = false;
        for (var date in datesToTry) {
          if (waterSuccess) break;
          String targetDate = _formatDate(date);
          String waterUrl = 'https://apis.data.go.kr/1192136/roms/getOceanModel?serviceKey=$apiKey&pageNo=1&numOfRows=10&dataType=JSON&date=$targetDate';
          final waterRes = await http.get(Uri.parse(waterUrl)).timeout(const Duration(seconds: 3));
          if (waterRes.statusCode == 200) {
            var resBody = jsonDecode(utf8.decode(waterRes.bodyBytes))['response'];
            if (resBody != null && resBody['body'] != null && resBody['body']['items']['item'] != null) {
              var items = resBody['body']['items']['item'] as List;
              if (items.isNotEmpty && items[0]['water_temp'] != null) {
                double wtValue = double.parse(items[0]['water_temp'].toString());
                water = '${wtValue.toStringAsFixed(1)}°C';
                waterSuccess = true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("수온 API 수신 실패");
      }
    }

    int currentMonth = now.month;
    double currentWaterTemp = 16.2;
    try {
      currentWaterTemp = double.parse(water.replaceAll('°C', ''));
    } catch (e) {
      currentWaterTemp = 16.2;
    }

    if (currentMonth >= 3 && currentMonth <= 5) {
      fish = currentWaterTemp >= 15.0 ? "수온이 올라 **벵에돔**과 **참돔** 낚시를 추천해요!" : "아직 바다가 차가워요. **볼락**과 **감성돔**이 제격이에요!";
    } else if (currentMonth >= 6 && currentMonth <= 8) {
      fish = currentWaterTemp >= 22.0 ? "여름 바다의 제왕! **무늬오징어**와 **돌돔**을 노려보세요." : "활성도가 좋습니다! **참돔**과 **농어**를 잡기 딱 좋아요.";
    } else if (currentMonth >= 9 && currentMonth <= 11) {
      fish = currentWaterTemp >= 18.0 ? "가을 낚시의 꽃, **감성돔**과 **쭈꾸미** 낚시 어떠세요?" : "수온이 떨어지고 있어요. 바닥층 **우럭**과 **쥐노래미**를 추천해요.";
    } else {
      fish = "겨울 바다의 묘미, **호루기**와 **방어**가 제철입니다!";
    }

    await Future.delayed(const Duration(milliseconds: 600)); 
    return WeatherScreenData(
      temperature: temp, 
      windSpeed: wind, 
      windDirection: windDir,
      windAngle: windDeg,
      waveHeight: wave, 
      waterTemp: water, 
      recommendedFish: fish,
      isOffline: offlineMode,
      updateTime: now,
    );
  }

  // 💡 당겨서 새로고침 실행 함수
  Future<void> _handleRefresh() async {
    final newData = await _fetchAllData();
    setState(() {
      _weatherDataFuture = Future.value(newData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherScreenData>(
      future: _weatherDataFuture,
      builder: (context, snapshot) {
        bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final data = snapshot.data ?? WeatherScreenData(
          temperature: '-', windSpeed: '-', windDirection: '-', windAngle: 0.0, waveHeight: '-', waterTemp: '-', 
          recommendedFish: '데이터를 불러오는 중입니다.', isOffline: false, updateTime: DateTime.now()
        );

        String amPm = data.updateTime.hour < 12 ? '오전' : '오후';
        int hour = data.updateTime.hour > 12 ? data.updateTime.hour - 12 : (data.updateTime.hour == 0 ? 12 : data.updateTime.hour);
        String timeStr = "${data.updateTime.year}.${data.updateTime.month.toString().padLeft(2, '0')}.${data.updateTime.day.toString().padLeft(2, '0')} $amPm $hour:${data.updateTime.minute.toString().padLeft(2, '0')}";

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFC), // 완전 흰색 대신 아주아주 연한 푸른빛 배경 (고급스러움)
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('현재 바다 상황', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                const SizedBox(height: 2),
                Text('업데이트: $timeStr', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: Colors.white, 
            foregroundColor: Colors.black87,
            elevation: 0, 
            actions: [
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
              const SizedBox(width: 8)
            ],
          ),
          body: Stack(
            children: [
              // 💡 RefreshIndicator로 감싸서 '당겨서 새로고침' 지원!
              RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFF1976D2),
                backgroundColor: Colors.white,
                child: Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(), // 콘텐츠가 적어도 당겨지게 설정
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), 
                    child: AnimatedOpacity(
                      opacity: isLoading ? 0.4 : 1.0, 
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (data.isOffline)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                              child: Row(
                                children: [
                                  Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("인터넷 연결이 끊겨 로컬 데이터를 표시합니다.", style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ),

                          _buildRecommendedFishSection(data.recommendedFish, data.updateTime.month),
                          const SizedBox(height: 28),
                          
                          Row(
                            children: const [
                              Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                              SizedBox(width: 6),
                              Text('실시간 해양 데이터 (부산 앞바다)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              _buildInfoCard("기온", data.temperature, null, Icons.thermostat, const Color(0xFFFF8A65)),
                              const SizedBox(width: 14),
                              // 💡 바람 카드는 풍향 데이터를 함께 넘겨줌!
                              _buildInfoCard("풍속", data.windSpeed, "${data.windDirection}", Icons.air, const Color(0xFF4DB6AC), windAngle: data.windAngle),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildInfoCard("파고", data.waveHeight, null, Icons.waves, const Color(0xFF7986CB)),
                              const SizedBox(width: 14),
                              _buildInfoCard("수온", data.waterTemp, null, Icons.water_drop, const Color(0xFF64B5F6)),
                            ],
                          ),
                          const SizedBox(height: 40), // 맨 아래 여백
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
                          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)]
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 60),
                              const SizedBox(height: 16),
                              Text(
                                "위험!\n현재 [$_currentDangerPlace]\n추락 위험 지역입니다!",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              const Text("(화면을 터치하면 닫힙니다)", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
    List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*'); 
    int start = 0;
    for (final Match m in exp.allMatches(text)) {
      if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), fontSize: 16)));
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    String seasonIcon = "❄️";
    if (month >= 3 && month <= 5) seasonIcon = "🌸";
    else if (month >= 6 && month <= 8) seasonIcon = "☀️";
    else if (month >= 9 && month <= 11) seasonIcon = "🍁";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), 
      decoration: BoxDecoration(
        color: const Color(0xFF243046), // 살짝 더 깊은 네이비
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -6 * _floatController.value), 
                child: child,
              );
            },
            child: Text(seasonIcon, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$month월 바다 추천", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                RichText(text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, fontFamily: 'Pretendard'), children: spans)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 프리미엄 카드로 업그레이드! (그림자 추가, 풍향 데이터 처리)
  Widget _buildInfoCard(String title, String value, String? subtitle, IconData icon, Color color, {double windAngle = 0.0}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: title == "풍속" 
                  ? Transform.rotate( // 바람 카드일 경우 풍향에 맞춰 화살표 회전
                      angle: (windAngle + 180) * 3.1415926535 / 180, 
                      child: Icon(Icons.navigation_rounded, color: color, size: 24))
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF868E96), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF212529))),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
            ]
          ],
        ),
      ),
    );
  }
}