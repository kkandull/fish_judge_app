import 'dart:io';
import 'package:flutter/material.dart';

import '../services/weather_service.dart';
import '../services/journal_aggregator.dart';
import 'ai_scan_screen.dart';
import 'weather_screen.dart';
import 'encyclopedia_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 홈 화면
//
// 구성:
//   1. 상단 인사말 + 날짜
//   2. 위치 기반 날씨/수온 요약 카드 (→ 상세는 WeatherScreen)
//   3. 안전 알림 (조건부 — 강풍/높은 파고 등)
//   4. 이달의 추천 어종
//   5. 🎣 큰 AI 판독 시작 버튼
//   6. 최근 조과 미리보기 (있는 경우만)
//
// 외부 의존:
//   - WeatherService.instance: API 호출 (싱글톤, 캐시 공유)
//   - JournalAggregator.instance: 도감/지도 데이터 통합 조회
//
// 탭 전환 콜백:
//   - 부모(MainSkeleton)에서 탭 전환 함수를 받아 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class HomeScreen extends StatefulWidget {
  /// 다른 탭으로 이동시키는 콜백. (예: AI 판독 탭으로 이동)
  /// 탭 인덱스: 0=홈, 1=AI판독, 2=도감, 3=지도, 4=커뮤니티
  final void Function(int index)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeatherData? _weather;
  List<JournalSummary> _recentRecords = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool force = false}) async {
    if (!force) setState(() => _loading = true);

    try {
      final results = await Future.wait([
        WeatherService.instance.fetchAll(forceRefresh: force),
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
    setState(() => _refreshing = true);
    await _loadAll(force: true);
    if (mounted) setState(() => _refreshing = false);
  }

  // ── 안전 경고 판단 ────────────────────────────────────────
  String? _getSafetyAlert(WeatherData w) {
    // 풍속 7m/s 이상이면 경고
    final wind = double.tryParse(w.windSpeed.replaceAll('m/s', '').trim());
    if (wind != null && wind >= 7.0) {
      return "강풍 주의 (${w.windSpeed}). 갯바위·방파제 낚시 시 안전에 유의하세요.";
    }
    return null;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return "늦은 시간이네요";
    if (hour < 12) return "좋은 아침입니다";
    if (hour < 18) return "즐거운 오후예요";
    if (hour < 21) return "좋은 저녁입니다";
    return "좋은 밤이에요";
  }

  String _getDateString() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${weekdays[now.weekday - 1]}요일";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFF007AFF),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    // 1. 헤더 (인사말 + 날짜)
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // 2. 날씨 요약 카드
                    if (_weather != null) _buildWeatherCard(_weather!),
                    const SizedBox(height: 12),

                    // 3. 안전 경고 (조건부)
                    if (_weather != null && _getSafetyAlert(_weather!) != null)
                      _buildSafetyAlert(_getSafetyAlert(_weather!)!),

                    // 오프라인 안내
                    if (_weather != null && _weather!.isOffline)
                      _buildOfflineBadge(),

                    const SizedBox(height: 16),

                    // 4. 이달의 추천 어종
                    if (_weather != null)
                      _buildRecommendedFishCard(_weather!),
                    const SizedBox(height: 20),

                    // 5. AI 판독 시작 큰 버튼
                    _buildAiScanCta(),
                    const SizedBox(height: 24),

                    // 6. 최근 조과 (있을 때만)
                    if (_recentRecords.isNotEmpty) _buildRecentRecords(),
                  ],
                ),
              ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 빌더 메서드들
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF212529),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getDateString(),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF868E96),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard(WeatherData w) {
    return GestureDetector(
      onTap: () {
        // 날씨 상세 화면으로 (별도 push, 탭 전환이 아님 — Phase 2에서 weather 탭 제거 시 변경)
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
                const Text(
                  '부산 앞바다',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatUpdateTime(w.updateTime),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMetric('🌡️', '기온', w.temperature),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.25)),
                _buildMetric('💧', '수온', w.waterTemp),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.25)),
                _buildMetric('🌬️', '풍속', w.windSpeed),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.25)),
                _buildMetric('🌊', '파고', w.waveHeight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String emoji, String label, String value) {
    // 단위 분리 (예: "16.4°C" → "16.4" + "°C")
    String mainValue = value;
    String unit = '';
    final unitMatch = RegExp(r'([\d.]+)(.*)').firstMatch(value);
    if (unitMatch != null) {
      mainValue = unitMatch.group(1) ?? value;
      unit = unitMatch.group(2) ?? '';
    }

    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: mainValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdateTime(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$amPm $h:${dt.minute.toString().padLeft(2, '0')} 갱신';
  }

  Widget _buildSafetyAlert(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 6),
          Text(
            "오프라인 — 캐시 데이터 표시중",
            style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedFishCard(WeatherData w) {
    final spans = _parseMarkdownBold(w.recommendedFish);
    
    final month = w.updateTime.month;
    if (month >= 3 && month <= 5) {
      
    } else if (month >= 6 && month <= 8) {
      
    } else if (month >= 9 && month <= 11) {
      
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$month월 바다 추천",
                  style: const TextStyle(
                    color: Color(0xFF868E96),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF212529),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    children: spans,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseMarkdownBold(String text) {
    final spans = <TextSpan>[];
    final exp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;
    for (final m in exp.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF007AFF),
        ),
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  Widget _buildAiScanCta() {
    return GestureDetector(
      onTap: () {
        // 탭 콜백 있으면 AI 판독 탭으로 이동
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // 1 = AI 판독 탭
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiScanScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007AFF), Color(0xFF00C2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🎣 AI 어종 판독 시작",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "사진 한 장으로 어종·금어기·체장을 즉시 확인",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecords() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "📅 최근 조과",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF212529),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                // 도감 탭으로 이동
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(2); // 2 = 도감
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EncyclopediaScreen()),
                  );
                }
              },
              child: const Row(
                children: [
                  Text(
                    "전체보기",
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      color: Color(0xFF007AFF), size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentRecords.map((r) => _buildRecordItem(r)),
      ],
    );
  }

  Widget _buildRecordItem(JournalSummary r) {
    return GestureDetector(
      onTap: () {
        // 💡 핵심: 물고기 카드를 누르면 도감 화면으로 이동하면서 '해당 어종 이름'을 타겟으로 넘겨줍니다!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EncyclopediaScreen(targetFish: r.fishName),
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
            // 썸네일 (사진 있으면 이미지, 없으면 이모지)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: r.imagePath != null && File(r.imagePath!).existsSync()
                  ? Image.file(
                      File(r.imagePath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildEmojiPlaceholder(),
                    )
                  : _buildEmojiPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.fishName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF212529),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (r.locationName != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 11, color: Color(0xFF868E96)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            r.locationName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF868E96),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (r.lengthCm != null || r.weightG != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (r.lengthCm != null)
                            Text(
                              "📏 ${r.lengthCm!.toStringAsFixed(1)}cm",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF007AFF),
                                  fontWeight: FontWeight.w700),
                            ),
                          if (r.weightG != null)
                            Text(
                              r.weightG! >= 1000
                                  ? "⚖️ ${(r.weightG! / 1000).toStringAsFixed(2)}kg"
                                  : "⚖️ ${r.weightG!.toStringAsFixed(0)}g",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF007AFF),
                                  fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _formatRelativeDate(r.catchTime),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFADB5BD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFF1F3F5),
      alignment: Alignment.center,
      child: const Text("🐟", style: TextStyle(fontSize: 28)),
    );
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return "${dt.month}/${dt.day}";
  }
}