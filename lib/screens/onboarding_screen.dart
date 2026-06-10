import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _kNavy = Color(0xFF0D1B2A);
const Color _kSub  = Color(0xFF607080);

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// 온보딩 페이지 데이터
class _OPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final List<String>? chips; // 하단 태그 목록

  const _OPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    this.chips,
  });
}

const List<_OPage> _pages = [
  // 1. 나우피싱 소개
  _OPage(
    emoji: '🎣',
    title: '낚시, 더 즐겁게',
    subtitle: '나우피싱 (NowFishing)',
    description: '전국 낚시인을 위한\n올인원 스마트 낚시 도우미',
    gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    chips: ['실시간 날씨·물때', '전국 포인트 지도', 'AI 어종 판독', '조과 도감', '낚시 커뮤니티'],
  ),

  // 2. AI 어종 판독
  _OPage(
    emoji: '📸',
    title: 'AI 어종 판독',
    subtitle: '10종 지원 · 사진 한 장으로 즉시 확인',
    description: '어종 식별 · 금어기 · 금지체장 · 독성 여부\n안전하고 올바른 낚시를 도와드려요',
    gradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    chips: ['광어', '도다리', '우럭', '볼락', '노래미', '쥐노래미', '독가시치', '감성돔', '참돔', '벵에돔'],
  ),

  // 3. 날씨·물때
  _OPage(
    emoji: '🌊',
    title: '실시간 날씨·물때',
    subtitle: '낚시 적합도 자동 계산',
    description: '기온·수온·풍속·파고·조석 예보\n오늘 낚시 가도 될지 한눈에 확인',
    gradient: [Color(0xFF00838F), Color(0xFF4DD0E1)],
    chips: ['기상청 실시간', '수온·파고', '만조·간조', '낚시 적합도', '기상특보 알림', '일출·일몰'],
  ),

  // 4. 전국 포인트
  _OPage(
    emoji: '🗺️',
    title: '전국 낚시 포인트',
    subtitle: '검증된 47개 포인트',
    description: '부산·경남·전남·제주·경북·강원\n인천·충남 전국 주요 낚시터 수록',
    gradient: [Color(0xFFE65100), Color(0xFFFF8A65)],
    chips: ['부산 해운대', '여수 돌산도', '서귀포 외돌개', '울릉도 저동항', '강릉 안목항', '태안 학암포'],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await OnboardingScreen.markCompleted();
    if (mounted) widget.onCompleted();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final btnColor = page.gradient.first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // 건너뛰기
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_currentPage < _pages.length - 1)
                TextButton(
                  onPressed: _complete,
                  style: TextButton.styleFrom(
                    foregroundColor: _kSub,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  child: const Text('건너뛰기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))
              else
                const SizedBox(height: 40),
            ]),
          ),

          // 페이지 콘텐츠
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _PageContent(page: _pages[i]),
            ),
          ),

          // 인디케이터
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: active ? btnColor : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
          ),

          // 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _currentPage < _pages.length - 1 ? '다음' : '시작하기',
                    key: ValueKey(_currentPage),
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                )),
            ),
          ),
        ]),
      ),
    );
  }
}

// 페이지 콘텐츠
class _PageContent extends StatelessWidget {
  final _OPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이모지 원형
          Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.gradient.first.withOpacity(0.28),
                  blurRadius: 28, offset: const Offset(0, 10)),
              ],
            ),
            child: Center(
              child: Text(page.emoji, style: const TextStyle(fontSize: 72))),
          ),
          const SizedBox(height: 32),

          // 서브타이틀
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 13, color: page.gradient.first,
              fontWeight: FontWeight.bold, letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),

          // 제목
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900,
              color: _kNavy, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),

          // 설명
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14, color: _kSub, height: 1.65, fontWeight: FontWeight.w500),
          ),

          // 칩 목록
          if (page.chips != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 7, runSpacing: 7,
              alignment: WrapAlignment.center,
              children: page.chips!.map((c) => _Chip(
                label: c, color: page.gradient.first)).toList(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12, color: color,
          fontWeight: FontWeight.w600),
      ),
    );
  }
}