import 'package:flutter/material.dart';
import 'screens/ai_scan_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/shop_screen.dart';

void main() {
  runApp(const SmartFishingApp());
}

class SmartFishingApp extends StatelessWidget {
  const SmartFishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fishing App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainSkeleton(), 
      debugShowCheckedModeBanner: false, 
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
      appBar: AppBar(
        title: const Text('스마트 낚시 플랫폼'),
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'AI 판독'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud), label: '날씨/수온'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '낚시 도감'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: '장비 추천'),
        ],
      ),
    );
  }
}