// 홈 스크린 

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../services/weather_service.dart';
import '../services/journal_aggregator.dart';
import '../services/feedback_service.dart';
import '../widgets/weather_alert_banner.dart';
import 'catch_record_detail_screen.dart';
import '../widgets/region_picker_sheet.dart';
import 'weather_screen.dart';
import 'encyclopedia_screen.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF212529);
const Color _kSub = Color(0xFF868E96);

// 데이터 모델

enum FishCategory { fish, crustacean, shellfish, seaweed, other }

class FishingRestriction {
  final String fishName;
  final String emoji;
  final FishCategory category;
  final List<int> restrictedMonths;
  final String? restrictionPeriod;
  final String? minSizeLabel;
  final String? sizeNote;
  final String? note;

  const FishingRestriction({
    required this.fishName,
    required this.emoji,
    required this.category,
    this.restrictedMonths = const [],
    this.restrictionPeriod,
    this.minSizeLabel,
    this.sizeNote,
    this.note,
  });
}

// 금어기 금지체장 

const List<FishingRestriction> kFishingRestrictions = [

  FishingRestriction(fishName: '대구', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [1, 2], restrictionPeriod: '1월 16일 ~ 2월 15일', minSizeLabel: '35cm 이하'),
  FishingRestriction(fishName: '문치가자미', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [12, 1], restrictionPeriod: '12월 1일 ~ 익년 1월 31일', minSizeLabel: '20cm 이하'),
  FishingRestriction(fishName: '연어', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [10, 11], restrictionPeriod: '10월 1일 ~ 11월 30일'),
  FishingRestriction(fishName: '전어', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [5, 6, 7], restrictionPeriod: '5월 1일 ~ 7월 15일',
    note: '강원특별자치도·경상북도 제외'),
  FishingRestriction(fishName: '쥐노래미', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [11, 12], restrictionPeriod: '11월 1일 ~ 12월 31일',
    minSizeLabel: '20cm 이하', note: '특정 해역 11월 15일 ~ 12월 14일'),
  FishingRestriction(fishName: '참홍어', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [6, 7], restrictionPeriod: '6월 1일 ~ 7월 15일', minSizeLabel: '체반폭 42cm 이하'),
  FishingRestriction(fishName: '참조기', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [7], restrictionPeriod: '7월 1일 ~ 7월 31일',
    minSizeLabel: '15cm 이하', note: '근해자망(유자망) 4월 22일 ~ 8월 10일 / 어획량 10% 미만 제외'),
  FishingRestriction(fishName: '갈치', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [7], restrictionPeriod: '7월 1일 ~ 7월 31일 (북위 33도 이북)',
    minSizeLabel: '항문장 18cm 이하', note: '근해채낚기·연안복합어업 제외 / 어획량 10% 미만 제외'),
  FishingRestriction(fishName: '고등어', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [4, 5, 6], restrictionPeriod: '4~6월 중 해양수산부 고시 1개월',
    minSizeLabel: '21cm 이하', note: '어획량 10% 미만 제외'),
  FishingRestriction(fishName: '말쥐치', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [5, 6, 7], restrictionPeriod: '5월 1일 ~ 7월 31일',
    minSizeLabel: '18cm 이하', note: '정치망·연안·구획어업 6월 1일 ~ 7월 31일'),
  FishingRestriction(fishName: '옥돔', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [7, 8], restrictionPeriod: '7월 21일 ~ 8월 20일'),
  FishingRestriction(fishName: '명태', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [1,2,3,4,5,6,7,8,9,10,11,12],
    restrictionPeriod: '연중 금어기 (1월 1일 ~ 12월 31일)'),
  FishingRestriction(fishName: '삼치', emoji: '🐟', category: FishCategory.fish,
    restrictedMonths: [5], restrictionPeriod: '5월 1일 ~ 5월 31일', minSizeLabel: '30cm 이하'),
  FishingRestriction(fishName: '감성돔', emoji: '🐠', category: FishCategory.fish,
    restrictedMonths: [5], restrictionPeriod: '5월 1일 ~ 5월 31일', minSizeLabel: '25cm 이하'),
  FishingRestriction(fishName: '참가자미', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '20cm 이하'),
  FishingRestriction(fishName: '돌돔', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '24cm 이하'),
  FishingRestriction(fishName: '참돔', emoji: '🐡', category: FishCategory.fish, minSizeLabel: '24cm 이하'),
  FishingRestriction(fishName: '넙치(광어)', emoji: '🐠', category: FishCategory.fish, minSizeLabel: '35cm 이하'),
  FishingRestriction(fishName: '농어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '30cm 이하'),
  FishingRestriction(fishName: '도루묵', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '11cm 이하'),
  FishingRestriction(fishName: '민어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '33cm 이하'),
  FishingRestriction(fishName: '방어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '30cm 이하'),
  FishingRestriction(fishName: '볼락', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '15cm 이하'),
  FishingRestriction(fishName: '붕장어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '35cm 이하'),
  FishingRestriction(fishName: '조피볼락(우럭)', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '23cm 이하'),
  FishingRestriction(fishName: '갯장어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '40cm 이하'),
  FishingRestriction(fishName: '미거지', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '40cm 이하'),
  FishingRestriction(fishName: '용가자미', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '20cm 이하'),
  FishingRestriction(fishName: '기름가자미', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '20cm 이하'),
  FishingRestriction(fishName: '청어', emoji: '🐟', category: FishCategory.fish, minSizeLabel: '20cm 이하'),

  FishingRestriction(fishName: '꽃게', emoji: '🦀', category: FishCategory.crustacean,
    restrictedMonths: [6,7,8,9], restrictionPeriod: '6~9월 중 해양수산부 고시 2개월 이내',
    minSizeLabel: '두흉갑장 6.4cm 이하', note: '어획량 5% 이상 포획 시 해당 / 일부 어업 제외'),
  FishingRestriction(fishName: '대게', emoji: '🦀', category: FishCategory.crustacean,
    restrictedMonths: [6,7,8,9,10,11], restrictionPeriod: '6월 1일 ~ 11월 30일',
    minSizeLabel: '두흉갑장 9cm 이하',
    note: '동경 131도30분 이동수역 6월~10월 / 특정 해역 4월~7월20일·10월~11월'),
  FishingRestriction(fishName: '붉은대게', emoji: '🦀', category: FishCategory.crustacean,
    restrictedMonths: [7,8], restrictionPeriod: '7월 10일 ~ 8월 25일',
    note: '강원특별자치도 연안자망어업 6월 1일 ~ 7월 10일'),
  FishingRestriction(fishName: '대하', emoji: '🦐', category: FishCategory.crustacean,
    restrictedMonths: [5,6], restrictionPeriod: '5월 1일 ~ 6월 30일'),

  FishingRestriction(fishName: '새조개', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [6,7,8,9], restrictionPeriod: '6월 16일 ~ 9월 30일',
    note: '부산·울산·경남·전남(일부)·제주 6월 1일 ~ 9월 30일'),
  FishingRestriction(fishName: '소라', emoji: '🐚', category: FishCategory.shellfish,
    restrictedMonths: [6,7,8], restrictionPeriod: '지역별 상이 (6~8월)',
    minSizeLabel: '각고 5cm 이하', sizeNote: '제주·울릉도·독도산 각고 7cm 이하',
    note: '여수 삼산면 6월 / 제주 6~8월 / 울릉·독도 6~7월'),
  FishingRestriction(fishName: '전복', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [9,10], restrictionPeriod: '9월 1일 ~ 10월 31일',
    minSizeLabel: '각장 7cm 이하', sizeNote: '제주산 각장 10cm 이하', note: '제주 10월 1일 ~ 12월 31일'),
  FishingRestriction(fishName: '코끼리조개', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [5,6], restrictionPeriod: '5월 1일 ~ 6월 30일',
    note: '강원특별자치도·경상북도에 한정'),
  FishingRestriction(fishName: '키조개', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [7,8], restrictionPeriod: '7월 1일 ~ 8월 31일',
    minSizeLabel: '각장 18cm 이하', sizeNote: '부산·울산·강원·경북·경남산에 한정'),
  FishingRestriction(fishName: '가리비', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [3,4,5,6], restrictionPeriod: '3월 1일 ~ 6월 30일 (특정 해역)',
    note: '경북 포항 앞바다 특정 좌표 해역에 한정'),
  FishingRestriction(fishName: '오분자기', emoji: '🦪', category: FishCategory.shellfish,
    restrictedMonths: [7,8], restrictionPeriod: '7월 1일 ~ 8월 31일', note: '제주특별자치도에 한정'),
  FishingRestriction(fishName: '마대오분자기', emoji: '🦪', category: FishCategory.shellfish,
    minSizeLabel: '각장 4cm 이하', note: '제주특별자치도산에 한정'),
  FishingRestriction(fishName: '기수재첩', emoji: '🦪', category: FishCategory.shellfish,
    minSizeLabel: '각장 1.5cm 이하'),

  FishingRestriction(fishName: '넓미역', emoji: '🌿', category: FishCategory.seaweed,
    restrictedMonths: [9,10,11], restrictionPeriod: '9월 1일 ~ 11월 30일',
    note: '제주특별자치도에 한정 / 제주지사 고시로 변경 가능'),
  FishingRestriction(fishName: '우뭇가사리', emoji: '🌿', category: FishCategory.seaweed,
    restrictedMonths: [11,12,1,2,3], restrictionPeriod: '11월 1일 ~ 익년 3월 31일'),
  FishingRestriction(fishName: '톳', emoji: '🌿', category: FishCategory.seaweed,
    restrictedMonths: [10,11,12,1], restrictionPeriod: '10월 1일 ~ 익년 1월 31일'),

  FishingRestriction(fishName: '해삼', emoji: '🌊', category: FishCategory.other,
    restrictedMonths: [7], restrictionPeriod: '7월 1일 ~ 7월 31일'),
  FishingRestriction(fishName: '살오징어', emoji: '🦑', category: FishCategory.other,
    restrictedMonths: [4,5], restrictionPeriod: '4월 1일 ~ 5월 31일',
    minSizeLabel: '외투장 15cm 이하',
    note: '근해채낚기·연안복합·정치망어업 4월만 / 어획량 20% 미만 제외'),
  FishingRestriction(fishName: '낙지', emoji: '🐙', category: FishCategory.other,
    restrictedMonths: [6], restrictionPeriod: '6월 1일 ~ 6월 30일',
    note: '시·도지사 고시로 4~9월 중 1개월 이상 지역별 별도 지정 가능'),
  FishingRestriction(fishName: '주꾸미', emoji: '🐙', category: FishCategory.other,
    restrictedMonths: [5,6,7,8], restrictionPeriod: '5월 11일 ~ 8월 31일'),
  FishingRestriction(fishName: '참문어', emoji: '🐙', category: FishCategory.other,
    restrictedMonths: [5,6], restrictionPeriod: '5월 16일 ~ 6월 30일',
    note: '시·도지사 고시로 5월 1일 ~ 9월 15일 중 46일 이상 별도 지정 가능'),
  FishingRestriction(fishName: '대문어', emoji: '🐙', category: FishCategory.other,
    minSizeLabel: '600g 이하'),
];

List<FishingRestriction> getCurrentMonthRestrictions() {
  final month = DateTime.now().month;
  return kFishingRestrictions.where((r) => r.restrictedMonths.contains(month)).toList();
}

List<FishingRestriction> getSizeRestrictedList() {
  return kFishingRestrictions.where((r) => r.minSizeLabel != null).toList();
}


// 홈 화면

class HomeScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeatherData? _weather;
  List<JournalSummary> _recentRecords = [];
  bool _loading = true;
  bool _hasError = false; // ⭐ 9번: 에러 상태
  static const _kFeedbackLaunchKey = 'feedback_launch_count';

  @override
  void initState() {
    super.initState();
    _loadAll();
    // 앱 3회 실행 후부터 피드백 팝업 표시 (매 5회마다 1회)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFeedbackPrompt());
  }

  Future<void> _checkFeedbackPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kFeedbackLaunchKey) ?? 0) + 1;
    await prefs.setInt(_kFeedbackLaunchKey, count);
    // 3회 이상 && 5의 배수 실행 시 팝업 표시 (3, 8, 13, 18...)
    if (count >= 3 && (count - 3) % 5 == 0 && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _showFeedbackPrompt();
    }
  }

  void _showFeedbackPrompt() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _FeedbackPromptDialog(),
    );
  }

  Future<void> _loadAll({bool force = false}) async {
    // force=true(지역 변경/새로고침)여도 기존 데이터 유지 (깜빡임 방지)
    if (!force) setState(() { _loading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        WeatherService.instance.fetch(forceRefresh: force),
        JournalAggregator.instance.getRecentRecords(limit: 3),
      ]);
      if (!mounted) return;
      setState(() {
        _weather = results[0] as WeatherData;
        _recentRecords = results[1] as List<JournalSummary>;
        _loading = false;
        _hasError = false;
      });

    } catch (e) {
      debugPrint('홈 로딩 실패: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }



  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadAll(force: true);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '늦은 시간이네요';
    if (hour < 12) return '좋은 아침입니다';
    if (hour < 18) return '즐거운 오후예요';
    if (hour < 21) return '좋은 저녁입니다';
    return '좋은 밤이에요';
  }

  String _getDateString() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${weekdays[now.weekday - 1]}요일';
  }

  String _formatUpdateTime(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$amPm $hour:${dt.minute.toString().padLeft(2, '0')} 갱신';
  }

  String? _getSafetyAlert(WeatherData w) {
    if (w.windSpeedMs >= 7.0) return '강풍 주의 (${w.windSpeedMs.toStringAsFixed(1)}m/s). 갯바위·방파제 낚시 시 안전에 유의하세요.';
    if (w.waveHeightM >= 1.5) return '높은 파고 (${w.waveHeightM.toStringAsFixed(1)}m). 안전 장비 필수.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final restrictions = getCurrentMonthRestrictions();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? _buildSkeleton() 
            : _hasError && _weather == null
                ? _buildErrorState() 
                : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: _kPrimary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          if (_weather != null) _buildWeatherCard(_weather!),
                          if (_weather != null && _weather!.alerts.isNotEmpty)
                            WeatherAlertBanner(alerts: _weather!.alerts),
                          const SizedBox(height: 12),
                          if (_weather != null && _getSafetyAlert(_weather!) != null)
                            _buildSafetyAlert(_getSafetyAlert(_weather!)!),
                          if (_weather != null) ...[
                            const SizedBox(height: 12),
                            _buildFishingScoreMini(_weather!.fishingScore),
                          ],
                          const SizedBox(height: 16),
                          _buildRecommendCard(),
                          const SizedBox(height: 12),
                          if (restrictions.isNotEmpty) ...[
                            _buildRestrictionBanner(restrictions),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 20),
                          _buildRecentRecords(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }


  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sk(160, 26), const SizedBox(height: 6),
        _sk(100, 16), const SizedBox(height: 24),
        _sk(double.infinity, 130, r: 20), const SizedBox(height: 12),
        _sk(double.infinity, 72, r: 14), const SizedBox(height: 16),
        _sk(double.infinity, 58, r: 16), const SizedBox(height: 12),
        _sk(double.infinity, 100, r: 18), const SizedBox(height: 20),
        _sk(80, 18), const SizedBox(height: 12),
        _sk(double.infinity, 70, r: 14), const SizedBox(height: 10),
        _sk(double.infinity, 70, r: 14),
      ]),
    );
  }

  Widget _sk(double w, double h, {double r = 8}) =>
      _ShimmerBox(width: w, height: h, radius: r);


  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.wifi_off_rounded, size: 36, color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          const Text('날씨 정보를 불러올 수 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
          const SizedBox(height: 8),
          const Text('인터넷 연결을 확인하고\n아래 버튼을 눌러 다시 시도해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kSub, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _hasError = false);
              _loadAll(force: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            label: const Text('다시 시도',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _hasError = false),
            child: const Text('오프라인으로 계속',
              style: TextStyle(fontSize: 12, color: _kSub))),
        ]),
      ),
    );
  }
  // 금어기 배너
  Widget _buildRestrictionBanner(List<FishingRestriction> restrictions) {
    final month = DateTime.now().month;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => FishingRestrictionScreen(
            currentMonthRestrictions: restrictions)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC00), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFFCC00), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFF5D4000)),
                const SizedBox(width: 4),
                Text('$month월 금어기',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF5D4000))),
              ]),
            ),
            const Spacer(),
            const Text('전체보기', style: TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, color: _kSub, size: 16),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: restrictions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = restrictions[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(r.fishName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                    ]),
                    const SizedBox(height: 2),
                    Text(r.minSizeLabel != null ? '${r.minSizeLabel} 금지' : '포획 금지',
                      style: const TextStyle(fontSize: 10, color: _kSub)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.info_outline, size: 13, color: _kSub),
            const SizedBox(width: 6),
            const Expanded(child: Text(
              '금지체장 이하 포획 시 과태료 부과 · 반드시 방류해주세요',
              style: TextStyle(fontSize: 11, color: _kSub, height: 1.4))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_getGreeting(),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _kNavy)),
      const SizedBox(height: 4),
      Text(_getDateString(),
        style: const TextStyle(fontSize: 13, color: _kSub, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildWeatherCard(WeatherData w) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(w.region.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final picked = await RegionPickerSheet.show(context, WeatherService.instance.selectedRegion);
                if (picked != null && mounted) {
                  await WeatherService.instance.selectRegion(picked);
                  // 지역 변경: 기존 날씨 데이터 초기화 후 새로 로드
                  setState(() { _weather = null; _loading = true; });
                  _loadAll(force: true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('변경', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
                ]),
              ),
            ),
            const Spacer(),
            Text(_formatUpdateTime(w.updatedAt), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _buildMetric(Icons.thermostat, '기온', '${w.airTempC.toStringAsFixed(1)}°C'),
            _divider(),
            _buildMetric(Icons.water_drop, '수온', '${w.waterTempC.toStringAsFixed(1)}°C'),
            _divider(),
            _buildMetric(Icons.air, '풍속', '${w.windSpeedMs.toStringAsFixed(1)}m/s'),
            _divider(),
            _buildMetric(Icons.waves, '파고', '${w.waveHeightM.toStringAsFixed(1)}m'),
          ]),
        ]),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25));

  Widget _buildMetric(IconData icon, String label, String value) {
    return Expanded(child: Column(children: [
      Icon(icon, color: Colors.white, size: 22),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
    ]));
  }

  Widget _buildSafetyAlert(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200)),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
          style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  Widget _buildFishingScoreMini(FishingScore score) {
    final color = Color(int.parse(score.colorHex));
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(_getScoreIcon(score.score), color: color, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('오늘의 낚시 적합도',
                style: TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: Text(score.grade,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${score.score}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1.0)),
              const Text(' / 100',
                style: TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w600)),
            ]),
          ])),
          const Icon(Icons.chevron_right, color: _kSub),
        ]),
      ),
    );
  }

  IconData _getScoreIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.thumb_up;
    if (score >= 40) return Icons.info_outline;
    return Icons.warning_amber_rounded;
  }

  Widget _buildRecommendCard() {
    final month = DateTime.now().month;
    final (recommendText, fishList) = _getMonthlyRecommend(month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$month월 바다 추천',
          style: const TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        RichText(text: TextSpan(
          style: const TextStyle(fontSize: 15, color: _kNavy, fontWeight: FontWeight.w800, height: 1.4),
          children: _buildRecommendSpans(recommendText, fishList),
        )),
      ]),
    );
  }

  List<InlineSpan> _buildRecommendSpans(String text, List<String> highlights) {
    final spans = <InlineSpan>[];
    int idx = 0;
    while (idx < text.length) {
      int matchStart = -1; String? matchFish;
      for (final fish in highlights) {
        final pos = text.indexOf(fish, idx);
        if (pos != -1 && (matchStart == -1 || pos < matchStart)) { matchStart = pos; matchFish = fish; }
      }
      if (matchStart == -1) { spans.add(TextSpan(text: text.substring(idx))); break; }
      if (matchStart > idx) spans.add(TextSpan(text: text.substring(idx, matchStart)));
      spans.add(TextSpan(text: matchFish,
        style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900)));
      idx = matchStart + matchFish!.length;
    }
    return spans;
  }

  (String, List<String>) _getMonthlyRecommend(int month) {
    switch (month) {
      case 1: case 2: return ('수온이 낮아 볼락과 우럭 낚시가 잘 돼요', ['볼락', '우럭']);
      case 3: case 4: return ('봄 시즌, 감성돔과 광어가 활성화돼요', ['감성돔', '광어']);
      case 5: case 6: return ('수온이 올라 벵에돔과 참돔 낚시를 추천해요', ['벵에돔', '참돔']);
      case 7: case 8: return ('여름철엔 농어와 갈치 낚시가 인기예요', ['농어', '갈치']);
      case 9: case 10: return ('가을 시즌, 감성돔과 벵에돔이 활발해요', ['감성돔', '벵에돔']);
      case 11: case 12: return ('겨울철엔 볼락과 우럭이 잘 잡혀요', ['볼락', '우럭']);
      default: return ('오늘의 추천 어종을 확인해보세요', []);
    }
  }

  Widget _buildRecentRecords() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('최근 조과',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kNavy)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onNavigateTab != null) { widget.onNavigateTab!(2); }
            else { Navigator.push(context, MaterialPageRoute(builder: (_) => const EncyclopediaScreen())); }
          },
          child: const Row(children: [
            Text('전체보기',
              style: TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, color: _kPrimary, size: 16),
          ])),
      ]),
      const SizedBox(height: 12),
      if (_recentRecords.isEmpty)
        _buildEmptyRecentCard()
      else
        ..._recentRecords.map((r) => _buildRecordItem(r)),
    ]);
  }

  // 낚시 팁 카드
  Widget _buildEmptyRecentCard() {
    final tips = _getFishingTips();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimary.withOpacity(0.06), const Color(0xFF42A5F5).withOpacity(0.03)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withOpacity(0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(6)),
              child: const Text('오늘의 낚시 팁',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            const Spacer(),
            Icon(Icons.lightbulb_outline, size: 14, color: _kPrimary.withOpacity(0.6)),
          ]),
          const SizedBox(height: 10),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 18, height: 18,
                margin: const EdgeInsets.only(right: 8, top: 1),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.check, size: 11, color: _kPrimary)),
              Expanded(child: Text(tip,
                style: const TextStyle(fontSize: 12, color: _kNavy, height: 1.4))),
            ]),
          )),
        ]),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_a_photo_outlined, size: 16, color: _kPrimary),
            const SizedBox(width: 8),
            Text('첫 조과 기록하기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kPrimary)),
          ]),
        ),
      ),
    ]);
  }

  List<String> _getFishingTips() {
    final month = DateTime.now().month;
    final hour = DateTime.now().hour;
    final tips = <String>[];
    if (hour >= 4 && hour < 8)
      tips.add('새벽 시간대는 어류 활성도가 높아 입질이 잦아요');
    else if (hour >= 18 && hour < 21)
      tips.add('저녁 노을 시간대는 볼락·감성돔 황금 타이밍이에요');
    else if (hour >= 21 || hour < 4)
      tips.add('야간 낚시는 구명조끼 등 안전 장비를 꼭 챙기세요');
    else
      tips.add('만조·간조 전후 1시간이 입질 황금 타이밍이에요');
    if (month >= 3 && month <= 5)
      tips.add('봄철엔 감성돔·광어가 얕은 수심으로 올라와요');
    else if (month >= 6 && month <= 8)
      tips.add('여름 갯바위에선 독성 어종 접촉에 주의하세요');
    else if (month >= 9 && month <= 11)
      tips.add('가을은 감성돔·벵에돔 최성수기예요');
    else
      tips.add('겨울철엔 볼락·도다리가 잘 잡히는 시즌이에요');
    tips.add('AI 판독으로 물고기를 찍으면 금어기·독성 여부를 즉시 알 수 있어요');
    return tips.take(3).toList();
  }

  Widget _buildRecordItem(JournalSummary r) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => CatchRecordDetailScreen(record: r.record))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: r.imagePath != null && File(r.imagePath!).existsSync()
                ? Image.file(File(r.imagePath!), width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildIconPlaceholder())
                : _buildIconPlaceholder()),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.fishName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kNavy)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.location_on, size: 11, color: _kSub),
              const SizedBox(width: 3),
              Expanded(child: Text(r.locationName ?? '위치 정보 없음',
                style: const TextStyle(fontSize: 11, color: _kSub), overflow: TextOverflow.ellipsis)),
            ]),
            if (r.lengthCm != null || r.weightG != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (r.lengthCm != null) ...[
                  const Icon(Icons.straighten, size: 11, color: _kPrimary),
                  const SizedBox(width: 3),
                  Text('${r.lengthCm!.toStringAsFixed(1)}cm',
                    style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.bold)),
                ],
                if (r.lengthCm != null && r.weightG != null) const SizedBox(width: 8),
                if (r.weightG != null) ...[
                  const Icon(Icons.monitor_weight_outlined, size: 11, color: _kPrimary),
                  const SizedBox(width: 3),
                  Text(
                    r.weightG! >= 1000
                      ? '${(r.weightG! / 1000).toStringAsFixed(2)}kg'
                      : '${r.weightG!.toStringAsFixed(0)}g',
                    style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.bold)),
                ],
              ]),
            ],
          ])),
          Text(_daysAgo(r.catchTime), style: const TextStyle(fontSize: 11, color: _kSub)),
        ]),
      ),
    );
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kPrimary.withOpacity(0.1), const Color(0xFF42A5F5).withOpacity(0.05)])),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: _kPrimary.withOpacity(0.5), size: 24));
  }

  String _daysAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    return '${(diff.inDays / 30).floor()}달 전';
  }
}

// 금어기 전체보기 화면

class FishingRestrictionScreen extends StatefulWidget {
  final List<FishingRestriction> currentMonthRestrictions;
  const FishingRestrictionScreen({super.key, required this.currentMonthRestrictions});

  @override
  State<FishingRestrictionScreen> createState() => _FishingRestrictionScreenState();
}

class _FishingRestrictionScreenState extends State<FishingRestrictionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now().month;
    final sizeList = getSizeRestrictedList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text('수산자원 보호 안내',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.w900, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            Container(height: 1, color: const Color(0xFFE8EAED)),
            TabBar(
              controller: _tabController,
              labelColor: _kPrimary,
              unselectedLabelColor: _kSub,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorColor: _kPrimary,
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: '$month월 금어기 (${widget.currentMonthRestrictions.length})'),
                Tab(text: '전체 금지체장 (${sizeList.length})'),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyTab(month),
          _buildSizeTab(sizeList),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab(int month) {
    final restrictions = widget.currentMonthRestrictions;
    if (restrictions.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 56),
        const SizedBox(height: 16),
        Text('$month월은 금어기 어종이 없어요!',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
        const SizedBox(height: 8),
        const Text('즐거운 낚시 되세요 🎣',
          style: TextStyle(fontSize: 13, color: _kSub)),
      ]));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildInfoBanner('아래 어종은 $month월 금어기 또는 금지체장 규정이 적용됩니다.\n위반 시 수산자원관리법에 따라 과태료가 부과됩니다.'),
      const SizedBox(height: 12),
      ...restrictions.map((r) => _buildRestrictionCard(r)),
      const SizedBox(height: 12),
      _buildLegalFooter(),
    ]);
  }

  Widget _buildSizeTab(List<FishingRestriction> sizeList) {
    final grouped = <FishCategory, List<FishingRestriction>>{};
    for (final r in sizeList) { grouped.putIfAbsent(r.category, () => []).add(r); }
    const categoryOrder = [FishCategory.fish, FishCategory.crustacean, FishCategory.shellfish, FishCategory.other];
    const categoryLabels = {
      FishCategory.fish: '어류 🐟',
      FishCategory.crustacean: '갑각류 🦀',
      FishCategory.shellfish: '패류 🦪',
      FishCategory.other: '기타 수산자원 🐙',
    };
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildInfoBanner('아래 체장(크기) 이하의 수산생물은 포획·채취가 금지됩니다.\n(수산자원관리법 시행령 별표 2 기준)'),
      const SizedBox(height: 12),
      for (final cat in categoryOrder)
        if (grouped.containsKey(cat)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(categoryLabels[cat]!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kNavy))),
          ...grouped[cat]!.map((r) => _buildSizeCard(r)),
          const SizedBox(height: 8),
        ],
      _buildLegalFooter(),
    ]);
  }

  Widget _buildSizeCard(FishingRestriction r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Text(r.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.fishName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.straighten, size: 12, color: _kPrimary),
            const SizedBox(width: 4),
            Text('${r.minSizeLabel} 포획 금지',
              style: const TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w700)),
          ]),
          if (r.sizeNote != null) ...[
            const SizedBox(height: 2),
            Text(r.sizeNote!, style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
          ],
          if (r.note != null) ...[
            const SizedBox(height: 2),
            Text(r.note!, style: const TextStyle(fontSize: 10, color: _kSub, height: 1.4)),
          ],
        ])),
        if (r.restrictedMonths.contains(DateTime.now().month))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFCDD2))),
            child: const Text('금어기',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFE53935)))),
      ]),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFFFF6F00), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFBF360C), height: 1.5))),
      ]),
    );
  }

  Widget _buildRestrictionCard(FishingRestriction r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text(r.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.fishName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kNavy)),
            const SizedBox(height: 6),
            if (r.restrictionPeriod != null)
              _infoRow(Icons.calendar_month, '금어기', r.restrictionPeriod!, const Color(0xFFE65100)),
            if (r.minSizeLabel != null) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.straighten, '금지체장', '${r.minSizeLabel} 포획 금지', _kPrimary),
            ],
            if (r.sizeNote != null) ...[
              const SizedBox(height: 2),
              _infoRow(Icons.place, '지역별', r.sizeNote!, Colors.orange.shade700),
            ],
            if (r.note != null) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.notes, '비고', r.note!, _kSub),
            ],
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2))),
            child: const Text('주의',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE53935)))),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text('$label: ', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      Expanded(child: Text(value,
        style: TextStyle(fontSize: 11, color: color.withOpacity(0.85), height: 1.4))),
    ]);
  }

  Widget _buildLegalFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.gavel, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(child: Text(
          '출처: 수산자원관리법 시행령 별표 1·2 (2026.1.1 기준)\n지역·어종별 세부 규정은 관할 해양수산청에 문의하세요.\n명태는 연중 포획이 금지되어 있습니다.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5))),
      ]),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width == double.infinity ? double.infinity : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(Colors.grey[200], Colors.grey[100], _anim.value),
          borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}


// 피드백 유도 팝업

class _FeedbackPromptDialog extends StatefulWidget {
  @override
  State<_FeedbackPromptDialog> createState() => _FeedbackPromptDialogState();
}

class _FeedbackPromptDialogState extends State<_FeedbackPromptDialog> {
  final _ctrl = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  bool _expanded = false; // 별점 탭 시 텍스트 필드 펼침

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 && _ctrl.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _submitting = true);
    try {
      await FeedbackService.instance.submitFeedback(
        type: 'prompt',
        content: _ctrl.text.isEmpty ? '별점만 제출' : _ctrl.text,
        rating: _rating > 0 ? _rating : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('소중한 의견 감사해요! 더 좋은 앱을 만들게요 🎣'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1976D2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // 물고기 아이콘
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🎣', style: TextStyle(fontSize: 26))),
          const SizedBox(height: 14),

          const Text('나우피싱은 어떠세요?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
          const SizedBox(height: 6),
          const Text('별점을 남겨주시면 앱 개선에 큰 도움이 돼요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kSub, height: 1.4)),
          const SizedBox(height: 20),

          // 별점
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => setState(() {
                _rating = i + 1;
                _expanded = true;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 38, color: filled ? const Color(0xFFFFC107) : const Color(0xFFDDE3EA))),
            );
          })),

          // 별점 탭 시 텍스트 필드 펼침
          if (_expanded) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              maxLength: 200,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '한 줄 의견도 좋아요! (선택)',
                hintStyle: const TextStyle(fontSize: 13, color: _kSub),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 버튼
          Row(children: [
            Expanded(child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('나중에',
                style: TextStyle(color: _kSub, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('제출',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    );
  }
}