import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 

class WeatherScreenData {
  final String temperature;
  final String windSpeed;
  final String waveHeight;
  final String waterTemp;
  final String recommendedFish;

  WeatherScreenData({
    required this.temperature,
    required this.windSpeed,
    required this.waveHeight,
    required this.waterTemp,
    required this.recommendedFish,
  });
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  Future<WeatherScreenData>? _weatherDataFuture;
  StreamSubscription<Position>? _positionStream; 
  
  bool _isDangerZone = false; 
  String _currentDangerPlace = ""; 
  bool _isDismissedManually = false; 
  
  // 💡 새로고침 중인지 강제로 체크할 변수 추가
  bool _isManualLoading = false; 

  late AnimationController _blinkController;

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
  }

  @override
  void dispose() {
    _positionStream?.cancel(); 
    _blinkController.dispose();
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

  Future<WeatherScreenData> _fetchAllData() async {
    String temp = '18.5°C';
    String wind = '2.3m/s';
    String wave = '0.5m 내외'; 
    String water = '16.2°C';
    String fish = '';

    DateTime now = DateTime.now();

    try {
      DateTime kmaTime = now.minute < 45 ? now.subtract(const Duration(hours: 1)) : now;
      String baseDate = _formatDate(kmaTime);
      String baseTime = "${kmaTime.hour.toString().padLeft(2, '0')}00";

      String kmaUrl = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst?serviceKey=$apiKey&pageNo=1&numOfRows=100&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=98&ny=76';
      final kmaRes = await http.get(Uri.parse(kmaUrl)).timeout(const Duration(seconds: 3));
      
      if (kmaRes.statusCode == 200) {
        var res = jsonDecode(utf8.decode(kmaRes.bodyBytes));
        if (res['response']['header']['resultCode'] == '00') {
          var items = res['response']['body']['items']['item'] as List;
          for (var item in items) {
            if (item['category'] == 'T1H') temp = '${item['obsrValue']}°C';
            if (item['category'] == 'WSD') wind = '${item['obsrValue']}m/s';
          }
        }
      }
    } catch (e) {
      debugPrint("API 에러 기본값 사용");
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
      debugPrint("수온 에러 기본값 사용");
    }

    int currentMonth = now.month;
    double currentWaterTemp = 16.2;
    try {
      currentWaterTemp = double.parse(water.replaceAll('°C', ''));
    } catch (e) {
      currentWaterTemp = 16.2;
    }

    if (currentMonth >= 3 && currentMonth <= 5) {
      if (currentWaterTemp >= 15.0) {
        fish = "🌸 $currentMonth월 봄바다 추천\n수온이 올라 **벵에돔**과 **참돔** 낚시를 추천해요!";
      } else {
        fish = "🌸 $currentMonth월 봄바다 추천\n아직 바다가 차가워요. **볼락**과 **감성돔**이 제격이에요!";
      }
    } else if (currentMonth >= 6 && currentMonth <= 8) {
      if (currentWaterTemp >= 22.0) {
        fish = "☀️ $currentMonth월 여름바다 추천\n여름 바다의 제왕! **무늬오징어**와 **돌돔**을 노려보세요.";
      } else {
        fish = "☀️ $currentMonth월 여름바다 추천\n활성도가 좋습니다! **참돔**과 **농어**를 잡기 딱 좋아요.";
      }
    } else if (currentMonth >= 9 && currentMonth <= 11) {
      if (currentWaterTemp >= 18.0) {
        fish = "🍁 $currentMonth월 가을바다 추천\n가을 낚시의 꽃, **감성돔**과 **쭈꾸미** 낚시 어떠세요?";
      } else {
        fish = "🍁 $currentMonth월 가을바다 추천\n수온이 떨어지고 있어요. 바닥층 **우럭**과 **쥐노래미**를 추천해요.";
      }
    } else {
      fish = "❄️ $currentMonth월 겨울바다 추천\n겨울 바다의 묘미, **호루기**와 **방어**가 제철입니다!";
    }

    // 💡 빙글빙글 도는 걸 확실히 보여주기 위해 1초 대기시간 부여
    await Future.delayed(const Duration(seconds: 1));
    return WeatherScreenData(temperature: temp, windSpeed: wind, waveHeight: wave, waterTemp: water, recommendedFish: fish);
  }

  // 💡 수동 새로고침 함수 따로 분리
  void _handleRefresh() async {
    setState(() {
      _isManualLoading = true; // 누르자마자 로딩 시작!
    });
    
    // 데이터를 새로 가져옴
    final newData = await _fetchAllData();
    
    setState(() {
      _weatherDataFuture = Future.value(newData);
      _isManualLoading = false; // 데이터 가져오면 로딩 끝!
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherScreenData>(
      future: _weatherDataFuture,
      builder: (context, snapshot) {
        // 💡 snapshot이 기다리는 중이거나, 사용자가 수동으로 버튼을 눌렀을 때 둘 다 '로딩'으로 취급
        bool isLoading = (snapshot.connectionState == ConnectionState.waiting) || _isManualLoading;
        final data = snapshot.data ?? WeatherScreenData(temperature: '18.5°C', windSpeed: '2.3m/s', waveHeight: '0.5m 내외', waterTemp: '16.2°C', recommendedFish: '바다 날씨를 불러오는 중입니다.');

        return Scaffold(
          backgroundColor: Colors.white, 
          appBar: AppBar(
            title: const Text('현재 바다 상황', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: Colors.white, 
            foregroundColor: Colors.black87,
            elevation: 0, 
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: isLoading
                    ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2.5)))
                    : IconButton(icon: const Icon(Icons.refresh, color: Colors.black54), onPressed: _handleRefresh),
              )
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), 
                  child: AnimatedOpacity(
                    opacity: isLoading ? 0.3 : 1.0, // 로딩 중엔 배경을 더 흐리게!
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRecommendedFishSection(data.recommendedFish),
                        const SizedBox(height: 32),
                        const Text('실시간 해양 데이터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildInfoCard("기온", data.temperature, Icons.thermostat, const Color(0xFFFF8A65)),
                            const SizedBox(width: 12),
                            _buildInfoCard("풍속", data.windSpeed, Icons.air, const Color(0xFF4DB6AC)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildInfoCard("파고", data.waveHeight, Icons.waves, const Color(0xFF7986CB)),
                            const SizedBox(width: 12),
                            _buildInfoCard("수온", data.waterTemp, Icons.water_drop, const Color(0xFF64B5F6)),
                          ],
                        ),
                      ],
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

  Widget _buildRecommendedFishSection(String text) {
    List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*'); 
    int start = 0;
    for (final Match m in exp.allMatches(text)) {
      if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), fontSize: 15)));
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24), 
      decoration: BoxDecoration(color: const Color(0xFF2B3A55), borderRadius: BorderRadius.circular(20)),
      child: RichText(text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, fontFamily: 'Pretendard'), children: spans)),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF868E96), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF343A40))),
          ],
        ),
      ),
    );
  }
}