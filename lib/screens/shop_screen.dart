import 'package:flutter/material.dart';
// TODO 1: pubspec.yaml에 shared_preferences: ^2.2.3 추가 후 아래 주석을 해제하세요.
// import 'package:shared_preferences/shared_preferences.dart';

// 🎯 [김승연 담당] 내 정보(에코 포인트) 및 수익화 샵 화면
// 
// 💡 [기획 의도 및 개발 가이드]
// 1. 에코 포인트 (로컬 DB): 방생을 통해 얻은 포인트를 shared_preferences에 저장하고 관리하세요.
//    포인트는 앱을 껐다 켜도 유지되어야 하며, 쿠폰 교환 시 차감되는 로직이 필요합니다.
// 2. 수익화 비전 (샵 UI): 실제 결제 기능은 필요 없으나, 낚시 용품점 광고 배너나 포인트로 교환 가능한 
//    아이템 리스트(GridView 등)를 배치해 서비스의 비즈니스 모델을 시각화하세요.
// 3. 편의시설 안내: 하단에 주변 낚시점이나 화장실 위치를 확인할 수 있는 버튼을 추가해 보세요.

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _ecoPoint = 0; // 로컬 DB에서 불러올 포인트 값

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    // TODO 2: SharedPreferences에서 현재 저장된 포인트를 불러오는 함수를 작성하세요.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 정보 & 피싱 샵', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🌱 1. 에코 포인트 카드 (그라데이션과 그림자를 활용해 고급스럽게 디자인하세요)
            _buildPointWallet(),
            const SizedBox(height: 25),

            // 📣 2. 제휴 낚시점 광고 배너 (이미지 위젯을 활용해 실제 광고처럼 꾸며보세요)
            _buildAdBanner(),
            const SizedBox(height: 25),

            // 🛒 3. 포인트 교환 상점 (GridView.builder를 사용해 아이템 리스트를 띄우세요)
            _buildItemGrid(),
          ],
        ),
      ),
    );
  }

  // --- 위젯 빌드 함수들 (AI에게 이 부분을 완성해달라고 하세요) ---

  Widget _buildPointWallet() {
    return Container(); // TODO 3: 포인트 수치와 '쿠폰 교환' 버튼 포함
  }

  Widget _buildAdBanner() {
    return Container(); // TODO 4: "부산 해운대 낚시할인마트 최대 20% 할인" 등의 배너
  }

  Widget _buildItemGrid() {
    return Container(); // TODO 5: 바늘, 찌, 목줄 등 포인트로 교환 가능한 상품 리스트
  }
}