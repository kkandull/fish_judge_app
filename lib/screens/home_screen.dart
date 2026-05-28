// lib/screens/home_screen.dart
//
// 홈 화면 - 이모지 최소화 버전.
// 카테고리/만조/간조 등 의미있는 곳에만 이모지 사용.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/weather_service.dart';
import '../services/journal_aggregator.dart';
import '../widgets/weather_alert_banner.dart';
import 'catch_record_detail_screen.dart';
import '../widgets/region_picker_sheet.dart';
import 'ai_scan_screen.dart';
import 'weather_screen.dart';
import 'encyclopedia_screen.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF212529);
const Color _kSub = Color(0xFF868E96);

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

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool force = false}) async {
    if (!force) setState(() => _loading = true);
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
      });
    } catch (e) {
      debugPrint('홈 로딩 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadAll(force: true);
  }

  // ✅ 인사말 - 이모지 제거
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
    if (w.windSpeedMs >= 7.0) {
      return '강풍 주의 (${w.windSpeedMs.toStringAsFixed(1)}m/s). 갯바위·방파제 낚시 시 안전에 유의하세요.';
    }
    if (w.waveHeightM >= 1.5) {
      return '높은 파고 (${w.waveHeightM.toStringAsFixed(1)}m). 안전 장비 필수.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
                      
                      // ⭐ 기상특보 배너 (특보 있을 때만)
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
                      const SizedBox(height: 20),
                      _buildAiScanCta(),
                      const SizedBox(height: 28),
                      _buildRecentRecords(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ✅ 헤더 - 이모지 제거
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getDateString(),
          style: const TextStyle(
            fontSize: 13,
            color: _kSub,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ 날씨 카드 - 이모지 → 아이콘 변경
  Widget _buildWeatherCard(WeatherData w) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeatherScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  w.region.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    final picked = await RegionPickerSheet.show(
                      context, WeatherService.instance.selectedRegion);
                    if (picked != null && mounted) {
                      await WeatherService.instance.selectRegion(picked);
                      _loadAll(force: true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('변경', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
                    ]),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatUpdateTime(w.updatedAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetric(Icons.thermostat, '기온', '${w.airTempC.toStringAsFixed(1)}°C'),
                _divider(),
                _buildMetric(Icons.water_drop, '수온', '${w.waterTempC.toStringAsFixed(1)}°C'),
                _divider(),
                _buildMetric(Icons.air, '풍속', '${w.windSpeedMs.toStringAsFixed(1)}m/s'),
                _divider(),
                _buildMetric(Icons.waves, '파고', '${w.waveHeightM.toStringAsFixed(1)}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25));
  }

  // ✅ 이모지 → Material 아이콘
  Widget _buildMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyAlert(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 낚시 적합도 - 아이콘만 (이모지 제거)
  Widget _buildFishingScoreMini(FishingScore score) {
    final color = Color(int.parse(score.colorHex));
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeatherScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_getScoreIcon(score.score), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '오늘의 낚시 적합도',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          score.grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${score.score}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        ' / 100',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _kSub),
          ],
        ),
      ),
    );
  }

  // 점수에 따른 아이콘
  IconData _getScoreIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.thumb_up;
    if (score >= 40) return Icons.info_outline;
    return Icons.warning_amber_rounded;
  }

  // ✅ 추천 카드 - 이모지 제거, 깔끔하게
  Widget _buildRecommendCard() {
    final month = DateTime.now().month;
    final (recommendText, fishList) = _getMonthlyRecommend(month);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month월 바다 추천',
            style: const TextStyle(
              fontSize: 12,
              color: _kSub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: _kNavy,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
              children: _buildRecommendSpans(recommendText, fishList),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildRecommendSpans(String text, List<String> highlights) {
    final spans = <InlineSpan>[];
    int idx = 0;
    while (idx < text.length) {
      int matchStart = -1;
      String? matchFish;
      for (final fish in highlights) {
        final pos = text.indexOf(fish, idx);
        if (pos != -1 && (matchStart == -1 || pos < matchStart)) {
          matchStart = pos;
          matchFish = fish;
        }
      }
      if (matchStart == -1) {
        spans.add(TextSpan(text: text.substring(idx)));
        break;
      }
      if (matchStart > idx) {
        spans.add(TextSpan(text: text.substring(idx, matchStart)));
      }
      spans.add(TextSpan(
        text: matchFish,
        style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900),
      ));
      idx = matchStart + matchFish!.length;
    }
    return spans;
  }

  (String, List<String>) _getMonthlyRecommend(int month) {
    switch (month) {
      case 1: case 2:
        return ('수온이 낮아 볼락과 우럭 낚시가 잘 돼요', ['볼락', '우럭']);
      case 3: case 4:
        return ('봄 시즌, 감성돔과 광어가 활성화돼요', ['감성돔', '광어']);
      case 5: case 6:
        return ('수온이 올라 벵에돔과 참돔 낚시를 추천해요', ['벵에돔', '참돔']);
      case 7: case 8:
        return ('여름철엔 농어와 갈치 낚시가 인기예요', ['농어', '갈치']);
      case 9: case 10:
        return ('가을 시즌, 감성돔과 벵에돔이 활발해요', ['감성돔', '벵에돔']);
      case 11: case 12:
        return ('겨울철엔 볼락과 우럭이 잘 잡혀요', ['볼락', '우럭']);
      default:
        return ('오늘의 추천 어종을 확인해보세요', []);
    }
  }

  // ✅ AI 판독 - 아이콘만
  Widget _buildAiScanCta() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiScanScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 어종 판독 시작',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '사진 한 장으로 어종·금어기·체장을 즉시 확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  // ✅ 최근 조과 헤더 - 이모지 제거
  Widget _buildRecentRecords() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '최근 조과',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _kNavy,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(2);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EncyclopediaScreen()),
                  );
                }
              },
              child: const Row(
                children: [
                  Text(
                    '전체보기',
                    style: TextStyle(
                      color: _kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: _kPrimary, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentRecords.isEmpty)
          _buildEmptyRecentCard()
        else
          ..._recentRecords.map((r) => _buildRecordItem(r)),
      ],
    );
  }

  // ✅ 빈 상태 카드 - 아이콘만
  Widget _buildEmptyRecentCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kPrimary.withOpacity(0.1),
                    const Color(0xFF00C2FF).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add_a_photo_outlined, color: _kPrimary, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              '아직 조과 기록이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI 판독으로 도감을 채워보세요',
              style: TextStyle(fontSize: 12, color: _kSub),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'AI 판독 시작',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordItem(JournalSummary r) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CatchRecordDetailScreen(record: r.record),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: r.imagePath != null && File(r.imagePath!).existsSync()
                ? Image.file(
                    File(r.imagePath!),
                    width: 56, height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildIconPlaceholder(),
                  )
                : _buildIconPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.fishName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 11, color: _kSub),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        r.locationName ?? '위치 정보 없음',
                        style: const TextStyle(fontSize: 11, color: _kSub),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (r.lengthCm != null || r.weightG != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (r.lengthCm != null) ...[
                        const Icon(Icons.straighten, size: 11, color: _kPrimary),
                        const SizedBox(width: 3),
                        Text(
                          '${r.lengthCm!.toStringAsFixed(1)}cm',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (r.lengthCm != null && r.weightG != null)
                        const SizedBox(width: 8),
                      if (r.weightG != null) ...[
                        const Icon(Icons.monitor_weight_outlined, size: 11, color: _kPrimary),
                        const SizedBox(width: 3),
                        Text(
                          r.weightG! >= 1000
                              ? '${(r.weightG! / 1000).toStringAsFixed(2)}kg'
                              : '${r.weightG!.toStringAsFixed(0)}g',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            _daysAgo(r.catchTime),
            style: const TextStyle(fontSize: 11, color: _kSub),
          ),
        ],
      ),
    ),   // Container
    );   // GestureDetector
  }

  // ✅ 이모지 → 아이콘
  Widget _buildIconPlaceholder() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPrimary.withOpacity(0.1),
            const Color(0xFF42A5F5).withOpacity(0.05),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: _kPrimary.withOpacity(0.5), size: 24),
    );
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