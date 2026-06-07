import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'ai_scan_screen.dart';
import 'encyclopedia_screen.dart';
import 'map_screen.dart';
import 'community_screen.dart';

const Color _kNavy    = Color(0xFF0D1B2A);
const Color _kPrimary = Color(0xFF1976D2);
const Color _kSub     = Color(0xFF6B7684);

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressedAt;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
    _lastBackPressedAt = null;
  }

  // ✅ PopScope의 onPopInvokedWithResult 핸들러
  void _handlePop(bool didPop, dynamic result) {
    if (didPop) return;

    // 1. 루트 Navigator에 쌓인 dialog/bottomSheet 먼저 닫기
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      _lastBackPressedAt = null;
      return;
    }

    // 2. 현재 탭 내부 Navigator에 쌓인 화면 닫기
    final currentNav = _navigatorKeys[_currentIndex].currentState;
    if (currentNav != null && currentNav.canPop()) {
      currentNav.pop();
      _lastBackPressedAt = null;
      return;
    }

    // 3. 홈 탭이 아니면 홈으로
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _lastBackPressedAt = null;
      return;
    }

    // 4. 홈 탭 루트에서 2초 안에 두 번 누르면 종료
    final now = DateTime.now();
    final isFirstPress = _lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2);

    if (isFirstPress) {
      _lastBackPressedAt = now;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('뒤로가기를 한 번 더 누르면 앱이 종료됩니다.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 두 번째 누름 → 종료
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ canPop: false → 시스템이 자동 pop 완전 차단
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(
                0, (_) => HomeScreen(onNavigateTab: _navigateToTab)),
            _buildTabNavigator(1, (_) => const AiScanScreen()),
            _buildTabNavigator(2, (_) => const EncyclopediaScreen()),
            _buildTabNavigator(3, (_) => const MyMapScreen()),
            _buildTabNavigator(4, (_) => const CommunityScreen()),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildTabNavigator(int index, WidgetBuilder rootBuilder) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: rootBuilder,
        settings: settings,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            _lastBackPressedAt = null;
          },
          selectedItemColor: _kPrimary,
          unselectedItemColor: _kSub,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt),
              label: 'AI 판독',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: '도감',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: '지도',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: '커뮤니티',
            ),
          ],
        ),
      ),
    );
  }
}