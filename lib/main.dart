import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/ai_scan_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ai_services.dart';
import 'services/catch_record_repository.dart';
import 'services/notification_service.dart';
import 'services/weather_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';

// ⭐ GPS용 추가 import
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

final aiService = AiService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.signInAnonymously();
  await ConnectivityService.instance.init();
  await NotificationService.instance.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await CatchRecordRepository.instance.init();
  await aiService.loadModel();

  // ⭐ WeatherService 초기화 (저장된 지역 복원)
  await WeatherService.instance.init();

  // ⭐ GPS 위치로 가장 가까운 낚시 지역 자동 선택
  await _autoSelectRegionByGps();

  runApp(const SmartFishingApp());
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ⭐ GPS → 가장 가까운 kFishingRegions 자동 선택
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> _autoSelectRegionByGps() async {
  try {
    // 1. 위치 권한 확인 (없으면 기본값(부산) 그대로)
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      debugPrint('GPS 권한 없음 → 기본 지역 유지');
      return;
    }

    // 2. GPS 서비스 켜져있는지 확인
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      debugPrint('GPS 꺼짐 → 기본 지역 유지');
      return;
    }

    // 3. 현재 위치 (타임아웃 5초)
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low, // 빠른 응답 우선
      timeLimit: const Duration(seconds: 5),
    );

    // 4. 가장 가까운 지역 찾기
    final nearest = _findNearestRegion(pos.latitude, pos.longitude);
    if (nearest != null) {
      await WeatherService.instance.selectRegion(nearest);
      debugPrint('✅ GPS 자동 지역: ${nearest.name} (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})');
    }
  } catch (e) {
    // GPS 실패해도 앱은 정상 실행 (기본값 유지)
    debugPrint('GPS 자동 선택 실패: $e');
  }
}

/// 위도/경도 → 가장 가까운 FishingRegion 반환
/// 단, 반경 150km 초과 시 null (해당 지역 없음 → 기본값 유지)
FishingRegion? _findNearestRegion(double lat, double lng) {
  const maxDistanceKm = 150.0;

  FishingRegion? nearest;
  double minDist = double.infinity;

  for (final region in kFishingRegions) {
    final dist = _haversineKm(lat, lng, region.lat, region.lng);
    if (dist < minDist) {
      minDist = dist;
      nearest = region;
    }
  }

  if (minDist > maxDistanceKm) {
    debugPrint('현재 위치가 지원 지역과 너무 멀어요 (${minDist.toStringAsFixed(0)}km) → 기본값 유지');
    return null;
  }

  return nearest;
}

/// Haversine 공식 — 두 좌표 간 거리 (km)
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0; // 지구 반지름 km
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat/2) * math.sin(dLat/2)
      + math.cos(_rad(lat1)) * math.cos(_rad(lat2))
      * math.sin(dLng/2) * math.sin(dLng/2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
}

double _rad(double deg) => deg * math.pi / 180;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 아래는 기존 main.dart 코드 그대로
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_showOnboarding) {
      return OnboardingScreen(onCompleted: () => setState(() => _showOnboarding = false));
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

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateTab: _onItemTapped),
      const AiScanScreen(),
      const EncyclopediaScreen(),
      const MyMapScreen(),
      const CommunityScreen(),
    ];
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<bool> _showExitDialog() async {
    final shouldExit = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "exit",
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.82,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 14))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF00C2FF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('앱 종료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF212529))),
              const SizedBox(height: 8),
              const Text('정말 나우피싱을 종료할까요?\n다음 출조도 안전하게 다녀오세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF6B7684), fontWeight: FontWeight.w500)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE8EAED)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7684))),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4B4B), elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('종료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                )),
              ]),
            ]),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => Transform.scale(
        scale: Curves.easeOutBack.transform(anim.value),
        child: Opacity(opacity: anim.value, child: child),
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return await _showExitDialog();
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
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
                  icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_outlined, size: 26)),
                  activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_rounded, size: 26)),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.camera_outlined, size: 26)),
                  activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.camera_rounded, size: 26)),
                  label: 'AI 판독',
                ),
                BottomNavigationBarItem(
                  icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.menu_book_outlined, size: 26)),
                  activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.menu_book, size: 26)),
                  label: '도감',
                ),
                BottomNavigationBarItem(
                  icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map_outlined, size: 26)),
                  activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map_rounded, size: 26)),
                  label: '지도',
                ),
                BottomNavigationBarItem(
                  icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.forum_outlined, size: 26)),
                  activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.forum_rounded, size: 26)),
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