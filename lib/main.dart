import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/home_screen.dart';
import 'screens/ai_scan_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/weather_service.dart';
import 'services/ai_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

final aiService = AiService();

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SmartFishingApp());
}

Future<void> autoSelectRegionByGps() async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
    final nearest = _findNearestRegion(pos.latitude, pos.longitude);
    if (nearest != null) await WeatherService.instance.selectRegion(nearest);
  } catch (_) {}
}

FishingRegion? _findNearestRegion(double lat, double lng) {
  FishingRegion? nearest;
  double minDist = double.infinity;
  for (final r in kFishingRegions) {
    final d = _haversineKm(lat, lng, r.lat, r.lng);
    if (d < minDist) {
      minDist = d;
      nearest = r;
    }
  }
  return minDist > 150.0 ? null : nearest;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1), dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double d) => d * math.pi / 180;

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
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showSplash = true;
  bool _checking = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final seen = await OnboardingScreen.hasSeenOnboarding();
    if (mounted) {
      setState(() {
        _showOnboarding = !seen;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
          onFinished: () => setState(() => _showSplash = false));
    }
    if (_checking) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding) {
      return OnboardingScreen(
          onCompleted: () => setState(() => _showOnboarding = false));
    }
    return const MainSkeleton();
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
  bool _isShowingExitDialog = false;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateTab: _onItemTapped),
      AiScanScreen(isActive: false),
      const EncyclopediaScreen(),
      const MyMapScreen(),
      const CommunityScreen(),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _screens[1] = AiScanScreen(isActive: index == 1);
    });
  }

  Future<void> _showExitDialog() async {
    if (_isShowingExitDialog) return;
    _isShowingExitDialog = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    )
                  ],
                ),
                child: const Icon(Icons.exit_to_app_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('앱 종료',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF212529))),
              const SizedBox(height: 8),
              const Text(
                '정말 나우피싱을 종료할까요?\n다음 출조도 안전하게 다녀오세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF6B7684)),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAED)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B7684))),
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
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('종료',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
      if (shouldExit == true) SystemNavigator.pop();
    } finally {
      if (mounted) _isShowingExitDialog = false;
    }
  }

  // ✅ 핵심: PopScope의 onPopInvokedWithResult 사용 (Flutter 3.12+)
  //    canPop: false → 시스템이 절대 자동으로 pop하지 않음
  //    onPopInvokedWithResult → 뒤로가기 눌릴 때마다 여기서 직접 처리
  void _handlePop(bool didPop, dynamic result) {
    if (didPop) return; // canPop: false 이므로 didPop은 항상 false

    // 1. 열려있는 dialog/bottomSheet가 있으면 그것만 닫기
    //    (루트 Navigator에 쌓인 overlay route 처리)
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
      return;
    }

    // 2. 홈 탭이 아니면 홈으로
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    // 3. 홈 탭에서는 종료 다이얼로그
    _showExitDialog();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ canPop: false → Flutter/안드로이드가 자동 pop 완전 차단
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(25)),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: const Color(0xFF007AFF),
              unselectedItemColor: Colors.grey.shade400,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.bold),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.home_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.home_rounded, size: 26)),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.camera_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.camera_rounded, size: 26)),
                  label: 'AI 판독',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.menu_book_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.menu_book, size: 26)),
                  label: '도감',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.map_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.map_rounded, size: 26)),
                  label: '지도',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.forum_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.forum_rounded, size: 26)),
                  label: '커뮤니티',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.settings_outlined, size: 26)),
                  activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.settings_rounded, size: 26)),
                  label: '설정',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}