import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  Future<WeatherData>? _weatherDataFuture;
  StreamSubscription<Position>? _positionStream;

  bool _isDangerZone = false;
  String _currentDangerPlace = "";
  bool _isDismissedManually = false;
  bool _isRefreshing = false;

  late AnimationController _blinkController;
  late AnimationController _floatController;

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
    _weatherDataFuture = WeatherService.instance.fetchAll();
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

  Future<void> _handleRefresh() async {
    final newData = await WeatherService.instance.fetchAll(forceRefresh: true);
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
      final newData =
          await WeatherService.instance.fetchAll(forceRefresh: true);
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
    return FutureBuilder<WeatherData>(
      future: _weatherDataFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final data = snapshot.data ?? WeatherData.placeholder();

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