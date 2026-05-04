import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/ai_scan_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/shop_screen.dart';
import 'services/ai_services.dart';

// 전역 변수로 선언하여 어디서든 접근 가능하게 만듭니다.
final aiService = AiService();

void main() async {
  // 비동기 작업을 위해 바인딩 확인
  WidgetsFlutterBinding.ensureInitialized();
  
  // 💡 [UX 디테일] 스마트폰 맨 위 상단바(시간/배터리)를 투명하게 만들어 풀스크린 감성 극대화
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  // 앱 시작 전 모델 미리 로드 (기존 조장님 로직 유지 - 아주 좋습니다!)
  await aiService.loadModel();
  
  runApp(const SmartFishingApp());
}

class SmartFishingApp extends StatelessWidget {
  const SmartFishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busan Fish App', 
      debugShowCheckedModeBanner: false, // 우측 상단 디버그 띠 제거
      theme: ThemeData(
        useMaterial3: true,
        // 💡 [UX 디테일] 바다 느낌이 나는 세련된 블루(Ocean Blue) 톤을 앱 전체 포인트 컬러로 지정
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainSkeleton(),
    );
  }
}

class MainSkeleton extends StatefulWidget {
  const MainSkeleton({super.key});

  @override
  State<MainSkeleton> createState() => _MainSkeletonState();
}

class _MainSkeletonState extends State<MainSkeleton> {
  int _selectedIndex = 0;

  // 조장님이 만드신 스크린들을 그대로 연결
  final List<Widget> _screens = [
    const AiScanScreen(),
    const WeatherScreen(),
    const EncyclopediaScreen(),
    const ShopScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 [핵심] 하단 바 밑의 공간까지 화면을 꽉 채우도록 허용 (카메라 꽉 찬 화면을 위해 필수)
      extendBody: true, 
      
      // 💡 [핵심] 전역 AppBar 제거 (카메라 화면을 가리지 않기 위함)
      body: _screens[_selectedIndex],
      
      // 💡 [UX 디테일] 트렌디하고 부드러운 하단 네비게이션 바 디자인
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // 은은한 그림자
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)), // 둥근 모서리
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed, 
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF007AFF), // 쨍한 블루 포인트
            unselectedItemColor: Colors.grey.shade400,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.camera_rounded, size: 26)),
                label: 'AI 판독',
              ),
              BottomNavigationBarItem(
                // 선택 안 됐을 땐 테두리만, 선택되면 색이 꽉 찬 아이콘 적용
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cloud_outlined, size: 26)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cloud, size: 26)),
                label: '날씨/수온',
              ),
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.menu_book_outlined, size: 26)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.menu_book, size: 26)),
                label: '낚시 도감',
              ),
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.shopping_cart_outlined, size: 26)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.shopping_cart, size: 26)),
                label: '샵/내정보',
              ),
            ],
          ),
        ),
      ),
    );
  }
}