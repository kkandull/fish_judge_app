import 'package:flutter/material.dart';
// TODO 1: pubspec.yaml에 http: ^1.2.1, geolocator: ^11.0.1 추가 후 아래 주석을 해제하세요.
// import 'package:http/http.dart' as http;
// import 'package:geolocator/geolocator.dart';

// 🎯 [표재국 담당] 실시간 날씨/수온 정보 및 위치 기반 안전 가이드 화면
// 
// 💡 [기획 의도 및 개발 가이드]
// 1. 실시간 데이터 (API 연동): 기상청 혹은 바다타임 API를 호출해 현재 부산의 기온, 풍속, 수온 정보를 가져오세요.
// 2. 안전 우선 (위치 기반): geolocator를 활용해 사용자가 위험 구역(테트라포드 등) 근처일 때 경고 배너를 띄워 사고를 방지합니다.
// 3. 조과 예측 (추천 어종): 현재 월(Month) 정보를 확인해 해당 계절에 활성도가 높은 어종(예: 5월은 벵에돔)을 추천해 줍니다.

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // TODO 2: API에서 받아온 데이터를 저장할 변수들을 선언하세요 (temp, wind, waterTemp 등).
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // TODO 3: 화면 초기화 시 지점 GPS 좌표를 가져오고 API를 호출하는 _fetchData()를 실행하세요.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('현재 바다 상황', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚨 1. 사고 위험 알림 배너 (빨간색 계열로 눈에 띄게 꾸며주세요)
                _buildSafetyBanner(),
                const SizedBox(height: 20),

                // 🌦️ 2. 실시간 날씨 & 수온 정보 카드 (Card 위젯과 Icon을 활용해 깔끔하게 디자인하세요)
                _buildWeatherInfoCard(),
                const SizedBox(height: 20),

                // 🔥 3. 오늘의 추천 대상어 (현재 기온/수온에 따른 텍스트 안내)
                _buildRecommendedFishSection(),
              ],
            ),
          ),
    );
  }

  // --- 위젯 빌드 함수들 (AI에게 이 부분을 완성해달라고 하세요) ---
  
  Widget _buildSafetyBanner() {
    return Container(); // TODO 4: "현재 위치는 테트라포드 추락 위험 지역입니다" 문구 포함
  }

  Widget _buildWeatherInfoCard() {
    return Container(); // TODO 5: 기온, 풍속, 파고, 수온 수치를 그리드나 리스트로 배치
  }

  Widget _buildRecommendedFishSection() {
    return Container(); // TODO 6: "지금은 벵에돔 활성도가 높습니다!" 같은 안내 문구
  }
}