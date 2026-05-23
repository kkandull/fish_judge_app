// lib/screens/root_screen.dart
//
// 앱 메인 진입점. 5탭 구조.
// 커뮤니티 탭은 기존 "곧 만나요!" 화면을 대체.
//
// ⚠️ 이 파일은 너 기존 root_screen.dart에 맞춰서 수정해야 함.
// 핵심은 커뮤니티 탭에 CommunityScreen 연결.

import 'package:flutter/material.dart';
// 기존 화면들 import
// import 'home_screen.dart';
// import 'ai_screen.dart';
// import 'encyclopedia_screen.dart';
// import 'map_screen.dart';
import 'community_screen.dart';

const Color _kNavy = Color(0xFF1A1A2E);
const Color _kPrimary = Color(0xFF1976D2);
const Color _kSub = Color(0xFF6B7684);

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;
  
  // 너 기존 화면으로 교체 필요
  final List<Widget> _screens = [
    const _PlaceholderScreen(title: '홈'),
    const _PlaceholderScreen(title: 'AI 판독'),
    const _PlaceholderScreen(title: '도감'),
    const _PlaceholderScreen(title: '지도'),
    const CommunityScreen(),  // ← 커뮤니티 탭
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
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
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: _kPrimary,
            unselectedItemColor: _kSub,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
              BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), activeIcon: Icon(Icons.camera_alt), label: 'AI 판독'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: '도감'),
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: '지도'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '커뮤니티'),
            ],
          ),
        ),
      ),
    );
  }
}

// 임시 placeholder (너 기존 화면으로 교체)
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title 화면')),
    );
  }
}
