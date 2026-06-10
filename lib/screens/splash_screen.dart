import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/fishing_score_ml_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/catch_record_repository.dart';
import '../services/weather_service.dart';
import '../services/ai_services.dart';
import '../main.dart' show aiService, autoSelectRegionByGps;

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _iconCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;

  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutBack));
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.easeIn));

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _initServices() async {
    await AuthService.instance.signInAnonymously();
    await GeminiService.instance.init();
    await FishingScoreMLService.instance.init();
    await ConnectivityService.instance.init();
    await NotificationService.instance.init();
    await CatchRecordRepository.instance.init();
    await aiService.loadModel();
    await WeatherService.instance.init();
    await autoSelectRegionByGps();
  }

  Future<void> _runSequence() async {
    FlutterNativeSplash.remove();
    final initFuture = _initServices();
    await _iconCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textCtrl.forward();
    await initFuture;
    await Future.delayed(const Duration(milliseconds: 400));
    await _exitCtrl.forward();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (ctx, _) => Opacity(
        opacity: _exitOpacity.value,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _iconCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _iconOpacity.value,
                    child: Transform.scale(
                      scale: _iconScale.value,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.25),
                            blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => SlideTransition(
                    position: _textSlide,
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(children: [
                        RichText(
                          text: const TextSpan(children: [
                            TextSpan(text: 'Now',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                                color: Color(0xFF1976D2), letterSpacing: -0.5)),
                            TextSpan(text: 'Fishing',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                                color: Color(0xFF212529), letterSpacing: -0.5)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        const Text('AI 낚시 어종 판독',
                          style: TextStyle(fontSize: 14, color: Color(0xFF868E96),
                            fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}