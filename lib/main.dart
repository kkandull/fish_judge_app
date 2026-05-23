import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/ai_scan_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart'; // ✅ 추가
import 'services/ai_services.dart';
import 'services/catch_record_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

// 전역 AI 서비스
final aiService = AiService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.instance.signInAnonymously();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // 🔄 통합 조과 저장소 초기화 (마이그레이션 자동 수행)
  await CatchRecordRepository.instance.init();

  // 🧠 AI 모델 미리 로드
  await aiService.loadModel();

  runApp(const SmartFishingApp());
}

class SmartFishingApp extends StatelessWidget {
  const SmartFishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '나우피싱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateTab: _onItemTapped),
      const AiScanScreen(),
      const EncyclopediaScreen(),
      const MyMapScreen(),
      const CommunityScreen(), // ✅ 자리표시자 → 진짜 커뮤니티 화면
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // ✅ 예쁜 종료 확인 다이얼로그
  Future<bool> _showExitDialog() async {
    final shouldExit = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "exit",
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.82,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 아이콘
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF00C2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.exit_to_app_rounded,
                        color: Colors.white, size: 30),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    "앱 종료",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF212529),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "정말 나우피싱을 종료할까요?\n다음 출조도 안전하게 다녀오세요 🎣",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF6B7684),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE8EAED)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B7684),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4B4B),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "종료",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curved,
          child: Opacity(
            opacity: anim.value,
            child: child,
          ),
        );
      },
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 홈 탭이 아니면 홈으로 이동
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }

        // 홈이면 종료 다이얼로그
        return await _showExitDialog();
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: const Color(0xFF007AFF),
              unselectedItemColor: Colors.grey.shade400,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.home_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.home_rounded, size: 26),
                  ),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.camera_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.camera_rounded, size: 26),
                  ),
                  label: 'AI 판독',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.menu_book_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.menu_book, size: 26),
                  ),
                  label: '도감',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.map_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.map_rounded, size: 26),
                  ),
                  label: '지도',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.forum_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.forum_rounded, size: 26),
                  ),
                  label: '커뮤니티',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}