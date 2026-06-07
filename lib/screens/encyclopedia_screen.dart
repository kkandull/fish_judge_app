// lib/screens/encyclopedia_screen.dart
// 🎨 완전 리디자인 — 실제 앱 수준 도감 화면
// 테마: 딥 네이비 + 민트/틸 액센트 + 부드러운 카드
// 실제 어종 이미지 느낌의 그라디언트 + 물고기 실루엣

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'post_compose_screen.dart';
import 'share_card.dart';
import 'catch_post_screen.dart';
import '../models/unified_catch_record.dart';
import '../services/catch_record_repository.dart';
import '../widgets/unified_catch_form.dart';
import '../widgets/fishing_stats_dashboard.dart';
import '../services/gemini_service.dart';
import '../services/weather_service.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 디자인 토큰
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const Color _kNavy     = Color(0xFF0D1B2A);
const Color _kBlue     = Color(0xFF1565C0);
const Color _kSky      = Color(0xFF1E88E5);
const Color _kTeal     = Color(0xFF00ACC1);
const Color _kMint     = Color(0xFF00BFA5);
const Color _kBg       = Color(0xFFF0F4F8);
const Color _kCard     = Colors.white;
const Color _kSub      = Color(0xFF607080);
const Color _kBorder   = Color(0xFFDDE3EA);
const Color _kOrange   = Color(0xFFFF6D00);
const Color _kRed      = Color(0xFFE53935);

// 어종별 테마 색상 (물고기 느낌)
const Map<String, List<Color>> _kFishColors = {
  '감성돔':   [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
  '참돔':    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  '벵에돔':  [Color(0xFF2D3436), Color(0xFF6C5CE7)],
  '노래미':  [Color(0xFF6C3483), Color(0xFFA569BD)],
  '우럭':    [Color(0xFF1A3A4A), Color(0xFF2980B9)],
  '볼락':    [Color(0xFF4A235A), Color(0xFF8E44AD)],
  '광어':    [Color(0xFF1B4332), Color(0xFF40916C)],
  '도다리':  [Color(0xFF1C3A2A), Color(0xFF52B788)],
  '독가시치':[Color(0xFF7B2D00), Color(0xFFE76F51)],
  '전갱이':  [Color(0xFF003566), Color(0xFF0077B6)],
};

const List<Color> _kDefaultFishColors = [Color(0xFF1A3A5C), Color(0xFF2980B9)];

List<Color> _fishGradient(String name) =>
    _kFishColors[name] ?? _kDefaultFishColors;

// 어종별 대표 실루엣 이모지 매핑 (더 다양하게)
const Map<String, String> _kFishEmoji = {
  '감성돔': '🐟', '참돔': '🐟', '벵에돔': '🐟', '노래미': '🐟',
  '쥐노래미': '🐟', '우럭': '🐟', '볼락': '🐟', '광어': '🐟',
  '도다리': '🐟', '독가시치': '🐟', '전갱이': '🐟', '고등어': '🐟', '삼치': '🐟',
};

const List<Map<String, dynamic>> kCommonGear = [
  {
    "name": "낚시대 + 릴 세트",
    "icon": "🎣",
    "color": Color(0xFF1976D2),
    "description": "입문자용 다용도 미니 낚시대 세트. 캠핑·바다낚시에 두루 사용 가능.",
    "url": "https://www.coupang.com/np/search?q=JAHCHO 캠핑 바다낚시 입문자용 다용도 미니 낚시대 세트",
  },
  {
    "name": "두레박",
    "icon": "🪣",
    "color": Color(0xFF00C2A8),
    "description": "EVA 접이식 두레박. 미끼 물 보관, 잡은 고기 임시 보관에 필수.",
    "url": "https://www.coupang.com/np/search?q=낚시+잇츠온 EVA 접이식 두레박",
  },
  {
    "name": "가위·집게",
    "icon": "✂️",
    "color": Color(0xFFFF8A65),
    "description": "다용도 스테인리스 낚시 가위 겸용 집게.",
    "url": "https://www.coupang.com/np/search?q=다용도 스테인리스 낚시 가위 겸용 집게",
  },
];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 메인 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class EncyclopediaScreen extends StatefulWidget {
  final File? capturedImage;
  final String? targetFish;
  const EncyclopediaScreen({super.key, this.capturedImage, this.targetFish});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen>
    with SingleTickerProviderStateMixin {
  final repo = CatchRecordRepository.instance;
  StreamSubscription? _changeSub;

  List<String> customFishNames = [];
  Map<String, List<UnifiedCatchRecord>> recordMap = {};
  bool _isLoading = true;
  bool _isGridView = true;
  late AnimationController _fadeCtrl;
  String? _patternInsight;      // Gemini 패턴 분석 결과
  bool _insightLoading = false; // 분석 중 상태
  String? _insightError;        // 에러 메시지
  static const _kInsightDateKey    = 'insight_last_date';
  static const _kInsightCacheKey   = 'insight_cached_text';

  List<String> get allFishNames =>
      [...CatchRecordRepository.defaultFishNames, ...customFishNames];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _loadData();
    _loadViewMode();
    _changeSub = repo.changes.listen((_) {
      if (mounted) _loadData(silent: true);
    });
    if (widget.targetFish != null && widget.capturedImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addRecordFromAi(widget.targetFish!, widget.capturedImage!);
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _changeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isGridView = prefs.getBool('encyclopedia_grid_view') ?? true);
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isGridView = !_isGridView);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('encyclopedia_grid_view', _isGridView);
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    customFishNames = await repo.getCustomFishList();
    final grouped = await repo.groupByFish();
    recordMap.clear();
    for (final name in allFishNames) {
      recordMap[name] = grouped[name] ?? [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward(from: 0);
      // 조과 기록 3개 이상이면 Gemini 패턴 분석 시작
      final allRecords = recordMap.values.expand((e) => e).toList();
      if (allRecords.length >= 3) _loadOrFetchInsight(allRecords);
    }
  }

  // 오늘 캐시 있으면 바로 표시, 없으면 Gemini 호출
  Future<void> _loadOrFetchInsight(List<UnifiedCatchRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // 'yyyy-MM-dd'
    final savedDate = prefs.getString(_kInsightDateKey) ?? '';
    final cachedText = prefs.getString(_kInsightCacheKey) ?? '';

    if (savedDate == today && cachedText.isNotEmpty) {
      // 오늘 이미 분석한 결과 → 캐시에서 바로 표시
      debugPrint('[Insight] 오늘 캐시 사용: $cachedText');
      if (mounted) setState(() => _patternInsight = cachedText);
      return;
    }

    // 오늘 아직 분석 안 했거나 캐시 없음 → Gemini 호출
    await _fetchPatternInsight(records);
  }

  Future<void> _fetchPatternInsight(List<UnifiedCatchRecord> records) async {
    if (!GeminiService.instance.isAvailable) return;
    if (!mounted) return;
    setState(() => _insightLoading = true);

    final weather = WeatherService.instance.cachedData;
    final insight = await GeminiService.instance.getPatternInsight(
      records: records,
      currentWaterTemp: weather?.waterTempC,
      currentMonth: DateTime.now().month,
    );

    if (mounted) {
      // await는 setState 밖에서
      final isQuota = insight == '__quota__';

      // 성공 시 캐시 저장 (setState 전에 처리)
      if (insight != null && !isQuota) {
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await prefs.setString(_kInsightDateKey, today);
        await prefs.setString(_kInsightCacheKey, insight);
        debugPrint('[Insight] 오늘 날짜로 캐시 저장 완료');
      }

      setState(() {
        _patternInsight = isQuota ? null : insight;
        _insightLoading = false;
        _insightError = isQuota
            ? '요청이 많아요. 내일 다시 확인해주세요 📅'
            : insight == null ? '분석 중 오류가 발생했어요' : null;
      });
    }
  }

  Future<void> _addRecordFromAi(String fishName, File tempFile) async {
    await showUnifiedCatchForm(context, prefilledFishName: fishName,
        prefilledImage: tempFile, createdFrom: 'ai_scan');
  }

  Future<void> _addPhotoToFish(String fishName) async {
    await showUnifiedCatchForm(context, prefilledFishName: fishName,
        createdFrom: 'encyclopedia');
  }

  // ── 갤러리 ────────────────────────────────────────
  void _showFishGallery(String fishName, List<UnifiedCatchRecord> records) {
    final colors = _fishGradient(fishName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (ctx, sc) => Container(
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // 헤더
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fishName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('${records.length}건 기록됨',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    ])),
                    GestureDetector(
                      onTap: () { Navigator.pop(ctx); _addPhotoToFish(fishName); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('기록 추가', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              ),
              // 그리드
              Expanded(
                child: GridView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.80),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final rec = records[i];
                    return _GalleryCard(
                      record: rec,
                      onTap: () { Navigator.pop(ctx); _showFishDetailPopup(context, rec); },
                      onDelete: () async { Navigator.pop(ctx); await _confirmDeleteRecord(context, rec); },
                      onPost: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CatchPostScreen(record: rec))); },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 상세 팝업 ─────────────────────────────────────
  void _showFishDetailPopup(BuildContext context, UnifiedCatchRecord record) {
    final colors = _fishGradient(record.fishName);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 이미지 헤더
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                height: 220, width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  record.hasPhoto
                      ? Image.file(File(record.imagePath!), fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => _FishHeroBg(fishName: record.fishName, record: record))
                      : _FishHeroBg(fishName: record.fishName, record: record),
                  // 그라디언트 오버레이
                  DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                    ),
                  )),
                  // 어종명
                  Positioned(bottom: 14, left: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(record.fishName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(_formatDate(record.catchTime),
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                    ]),
                  ),
                  // 닫기
                  Positioned(top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16)),
                    ),
                  ),
                ]),
              ),
            ),
            // 정보
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // 통계 칩들
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (record.lengthCm != null) _StatChip(
                    icon: Icons.straighten, label: '${record.lengthCm!.toStringAsFixed(1)} cm',
                    color: _kSky),
                  if (record.weightG != null) _StatChip(
                    icon: Icons.monitor_weight_outlined,
                    label: record.weightG! >= 1000
                        ? '${(record.weightG!/1000).toStringAsFixed(2)} kg'
                        : '${record.weightG!.toStringAsFixed(0)} g',
                    color: _kOrange),
                  if (record.count > 1) _StatChip(
                    icon: Icons.format_list_numbered,
                    label: '${record.count}마리', color: _kMint),
                ]),
                if (record.displayLocation != '위치 정보 없음') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.location_on, size: 14, color: _kSub),
                    const SizedBox(width: 4),
                    Expanded(child: Text(record.displayLocation,
                        style: const TextStyle(fontSize: 12, color: _kSub))),
                  ]),
                ],
                if (record.memo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(record.memo,
                        style: const TextStyle(fontSize: 13, color: _kNavy, height: 1.5)),
                  ),
                ],
                const SizedBox(height: 14),
                // 버튼들
                Row(children: [
                  Expanded(child: _ActionBtn(
                    icon: Icons.edit_outlined, label: '편집', color: _kBlue,
                    onTap: () async { Navigator.pop(ctx); await _showEditMemoDialog(record); })),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(
                    icon: Icons.article_outlined, label: '글 만들기', color: _kMint,
                    onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CatchPostScreen(record: record))); })),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _ActionBtn(
                    icon: Icons.forum_outlined, label: '커뮤니티', color: _kOrange,
                    onTap: () { Navigator.pop(ctx); _shareToCommunity(record); })),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(
                    icon: Icons.delete_outline, label: '삭제', color: _kRed,
                    onTap: () async { Navigator.pop(ctx); await _confirmDeleteRecord(context, record); })),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final ap = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')} $ap $h:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _shortDate(DateTime dt) {
    final d = DateTime.now().difference(dt).inDays;
    if (d == 0) return '오늘';
    if (d == 1) return '어제';
    if (d < 7) return '$d일 전';
    return '${dt.month}/${dt.day}';
  }

  String _weightLabel(double g) => g >= 1000
      ? '${(g/1000).toStringAsFixed(2)} kg' : '${g.toStringAsFixed(0)} g';

  Future<void> _shareToCommunity(UnifiedCatchRecord record) async {
    if (!record.hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진이 있는 기록만 커뮤니티에 공유할 수 있어요'),
            behavior: SnackBarBehavior.floating));
      return;
    }
    // ✅ 파일 존재 여부 확인
    final imageFile = File(record.imagePath!);
    final exists = await imageFile.exists();
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 파일을 찾을 수 없어요. 갤러리에서 직접 선택해주세요.'),
          behavior: SnackBarBehavior.floating));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PostComposeScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostComposeScreen(
      prefilledFishName: record.fishName, prefilledImage: imageFile)));
  }

  Future<void> _showEditMemoDialog(UnifiedCatchRecord record) async {
    final memoCtrl = TextEditingController(text: record.memo);
    final lengthCtrl = TextEditingController(
        text: record.lengthCm?.toStringAsFixed(1) ?? '');
    final weightCtrl = TextEditingController(
        text: record.weightG?.toStringAsFixed(0) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('기록 편집', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kBlue)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _TextField(ctrl: memoCtrl, label: '메모', hint: '포인트, 미끼, 날씨 등', icon: Icons.edit_note, maxLines: 3),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _TextField(ctrl: lengthCtrl, label: '길이', hint: 'cm', icon: Icons.straighten, isNumber: true, suffix: 'cm')),
            const SizedBox(width: 10),
            Expanded(child: _TextField(ctrl: weightCtrl, label: '무게', hint: 'g', icon: Icons.monitor_weight_outlined, isNumber: true, suffix: 'g')),
          ]),
        ])),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(ctx), child: const Text('취소'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                Navigator.pop(ctx);
                await repo.update(record.copyWith(
                  memo: memoCtrl.text.trim(),
                  lengthCm: double.tryParse(lengthCtrl.text),
                  weightG: double.tryParse(weightCtrl.text),
                ));
              },
              child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ],
      ),
    );
  }

  Future<void> _showAddCustomFishDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('새 어종 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kBlue)),
        content: _TextField(ctrl: nameCtrl, label: '어종 이름', hint: '예: 농어, 광어', icon: Icons.set_meal),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(ctx), child: const Text('취소'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await repo.addCustomFish(name);
              },
              child: const Text('추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFish(BuildContext ctx, String fishName) async {
    final ok = await showDialog<bool>(context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('어종 삭제'),
        content: Text("'$fishName' 어종과 관련된 모든 기록을 삭제할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, elevation: 0),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      for (final r in recordMap[fishName] ?? <UnifiedCatchRecord>[]) {
        if (r.imagePath != null) { try { final f = File(r.imagePath!); if (await f.exists()) await f.delete(); } catch (_) {} }
      }
      await repo.deleteByFish(fishName);
    }
  }

  Future<void> _confirmDeleteRecord(BuildContext ctx, UnifiedCatchRecord record) async {
    final ok = await showDialog<bool>(context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, elevation: 0),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      if (record.imagePath != null) { try { final f = File(record.imagePath!); if (await f.exists()) await f.delete(); } catch (_) {} }
      await repo.delete(record.id);
    }
  }

  void _openGearShop() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const GearShopScreen()));

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kBlue)));
    }

    final collected = allFishNames.where((n) => recordMap[n]?.isNotEmpty ?? false).length;
    final total = allFishNames.length;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('낚시 도감',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _kNavy)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder)),
        actions: [
          // 뷰 토글
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewToggleBtn(icon: Icons.grid_view_rounded, active: _isGridView,
                  onTap: () { if (!_isGridView) _toggleViewMode(); }),
              _ViewToggleBtn(icon: Icons.view_list_rounded, active: !_isGridView,
                  onTap: () { if (_isGridView) _toggleViewMode(); }),
            ]),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0,-2))],
        ),
        child: ElevatedButton.icon(
          onPressed: _showAddCustomFishDialog,
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text('어종 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, elevation: 0, minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(delegate: SliverChildListDelegate([
                const FishingStatsDashboard(),
                const SizedBox(height: 12),
                _buildGearShopButton(),
                const SizedBox(height: 12),
                // ⭐ Gemini 낚시 패턴 분석 카드
                _buildPatternInsightCard(),
                const SizedBox(height: 20),
                // 섹션 헤더
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kBlue, _kSky]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$collected / $total 종',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  const Text('어종 도감', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
                ]),
                const SizedBox(height: 8),
                // ⭐ 7번: 처음 방문 안내 (0종일 때만)
                if (collected == 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBlue.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 14, color: _kBlue.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text(
                        'AI 판독으로 물고기를 찍으면 자동으로 도감이 채워져요 📷',
                        style: TextStyle(
                          fontSize: 11, color: _kBlue, height: 1.4, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],

              ])),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 120),
              sliver: _isGridView
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, idx) {
                          final name = allFishNames[idx];
                          final records = recordMap[name] ?? <UnifiedCatchRecord>[];
                          final isCustom = customFishNames.contains(name);
                          return _FishGridCard(
                            fishName: name, records: records, isCustom: isCustom,
                            onTap: records.isEmpty ? () => _addPhotoToFish(name) : () => _showFishGallery(name, records),
                            onPhotoAdd: () => _addPhotoToFish(name),
                            onFishDelete: isCustom ? () => _confirmDeleteFish(context, name) : null,
                          );
                        },
                        childCount: allFishNames.length,
                      ),
                    )
                  : SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final name = allFishNames[idx];
                        final records = recordMap[name] ?? <UnifiedCatchRecord>[];
                        final isCustom = customFishNames.contains(name);
                        return _FishListCard(
                          fishName: name, records: records, isCustom: isCustom,
                          onPhotoAdd: () => _addPhotoToFish(name),
                          onRecordTap: (r) => _showFishDetailPopup(context, r),
                          onRecordDelete: (r) => _confirmDeleteRecord(context, r),
                          onFishDelete: isCustom ? () => _confirmDeleteFish(context, name) : null,
                        );
                      },
                      childCount: allFishNames.length,
                    )),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⭐ C. Gemini 낚시 패턴 분석 카드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPatternInsightCard() {
    final allRecords = recordMap.values.expand((e) => e).toList();
    final hasEnough = allRecords.length >= 3;
    final isGeminiOff = !GeminiService.instance.isAvailable;

    // Gemini 비활성화 상태면 카드 숨김
    if (isGeminiOff) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D1B2A), const Color(0xFF1A3A5C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: const Color(0xFF0D1B2A).withOpacity(0.3),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // 헤더
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('✨', style: TextStyle(fontSize: 10)),
              SizedBox(width: 3),
              Text('AI 낚시 패턴 분석',
                style: TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          if (hasEnough && !_insightLoading)
            GestureDetector(
              onTap: () async {
                // 캐시 초기화 후 재호출 (하루 1회 제한 무시하고 강제 갱신)
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_kInsightDateKey);
                await prefs.remove(_kInsightCacheKey);
                setState(() {
                  _patternInsight = null;
                  _insightLoading = false;
                  _insightError = null;
                });
                _fetchPatternInsight(allRecords);
              },
              child: Icon(Icons.refresh_rounded,
                color: Colors.white.withOpacity(0.5), size: 18)),
          if (hasEnough && _insightLoading)
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white.withOpacity(0.4))),
        ]),
        const SizedBox(height: 12),

        // 내용 분기
        if (!hasEnough) ...[
          // 기록 부족
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('🎣', style: TextStyle(fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('조과 기록을 더 쌓아보세요',
                style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('기록 ${allRecords.length}개 / 3개 이상이면 AI가 패턴을 분석해드려요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 11, height: 1.4)),
            ])),
          ]),
          const SizedBox(height: 10),
          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: allRecords.length / 3,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: const Color(0xFF42A5F5),
              minHeight: 4,
            ),
          ),
        ] else if (_insightLoading) ...[
          // 분석 중
          Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white.withOpacity(0.6))),
            const SizedBox(width: 10),
            Text('AI가 낚시 패턴을 분석 중이에요...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ]),
        ] else if (_patternInsight != null) ...[
          // 분석 결과
          Text(_patternInsight!,
            style: const TextStyle(
              color: Colors.white, fontSize: 13,
              height: 1.65, fontWeight: FontWeight.w400)),
        ] else ...[
          // Gemini 응답 없음 (오류)
          Row(children: [
            Icon(Icons.info_outline, size: 13,
              color: Colors.white.withOpacity(0.4)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _insightError ?? '분석을 불러올 수 없어요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 12))),
          ]),
        ],

      ]),
    );
  }

  Widget _buildGearShopButton() {
    return GestureDetector(
      onTap: _openGearShop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EAED)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('장비 추천 보기',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Color(0xFF212529))),
              SizedBox(height: 3),
              Text('낚시 입문자를 위한 필수 장비 3종',
                style: TextStyle(fontSize: 12, color: Color(0xFF868E96))),
            ],
          )),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF868E96)),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 물고기 히어로 배경 (사진 없을 때)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FishHeroBg extends StatelessWidget {
  final String fishName;
  final UnifiedCatchRecord? record;
  const _FishHeroBg({required this.fishName, this.record});

  @override
  Widget build(BuildContext context) {
    final colors = _fishGradient(fishName);
    final emoji = record?.emoji ?? _kFishEmoji[fishName] ?? '🐟';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        // 물결 패턴
        Positioned.fill(child: CustomPaint(painter: _WavePainter(
            color: Colors.white.withOpacity(0.06)))),
        // 이모지 + 이름
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20)),
            child: Text(fishName,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ])),
      ]),
    );
  }
}

// 물결 배경 패턴
class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final path = Path();
      final y = size.height * (0.3 + i * 0.18);
      path.moveTo(0, y);
      for (double x = 0; x <= size.width; x += 20) {
        path.cubicTo(x+5, y-8, x+15, y+8, x+20, y);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 그리드 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FishGridCard extends StatelessWidget {
  final String fishName;
  final List<UnifiedCatchRecord> records;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback onPhotoAdd;
  final VoidCallback? onFishDelete;

  const _FishGridCard({
    required this.fishName, required this.records, required this.isCustom,
    required this.onTap, required this.onPhotoAdd, this.onFishDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCollected = records.isNotEmpty;
    final firstRecord = isCollected ? records.first : null;
    final hasPhoto = firstRecord?.hasPhoto ?? false;
    final colors = _fishGradient(fishName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isCollected ? colors[0].withOpacity(0.15) : Colors.black.withOpacity(0.04),
              blurRadius: isCollected ? 12 : 6, offset: const Offset(0,3)),
          ],
          border: Border.all(
            color: isCollected ? colors[0].withOpacity(0.2) : _kBorder, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 이미지 영역
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(fit: StackFit.expand, children: [
                // 배경
                if (hasPhoto)
                  Image.file(File(firstRecord!.imagePath!), fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => _FishHeroBg(fishName: fishName, record: firstRecord))
                else if (isCollected)
                  _FishHeroBg(fishName: fishName, record: firstRecord)
                else
                  _UncollectedBg(fishName: fishName),

                // 수집 배지
                if (records.length > 1)
                  Positioned(top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors[0], borderRadius: BorderRadius.circular(10)),
                      child: Text('${records.length}', style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),

                // 삭제 (커스텀)
                if (onFishDelete != null)
                  Positioned(top: 8, left: 8,
                    child: GestureDetector(
                      onTap: onFishDelete,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: _kRed, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 13)),
                    ),
                  ),

                // 수집됨 표시
                if (isCollected)
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)])),
                      child: Center(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kMint, borderRadius: BorderRadius.circular(8)),
                        child: const Text('수집 완료', style: TextStyle(
                            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      )),
                    ),
                  ),
              ]),
            ),
          ),

          // 하단 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fishName, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: isCollected ? _kNavy : Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(isCollected ? '${records.length}건' : '미수집',
                    style: TextStyle(fontSize: 10,
                        color: isCollected ? colors[0] : Colors.grey.shade400,
                        fontWeight: isCollected ? FontWeight.w600 : FontWeight.normal)),
              ])),
              GestureDetector(
                onTap: onPhotoAdd,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_a_photo, size: 15, color: _kBlue)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// 미수집 배경
class _UncollectedBg extends StatelessWidget {
  final String fishName;
  const _UncollectedBg({required this.fishName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFECF0F4), const Color(0xFFDDE3EA)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // 물고기 실루엣 (흐릿한 느낌)
        Opacity(opacity: 0.25,
          child: Text(_kFishEmoji[fishName] ?? '🐟',
              style: const TextStyle(fontSize: 52))),
        const SizedBox(height: 4),
        Text('미수집', style: TextStyle(
            fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold,
            letterSpacing: 1.0)),
      ]),
    );
  }
}

// 리스트 카드
class _FishListCard extends StatelessWidget {
  final String fishName;
  final List<UnifiedCatchRecord> records;
  final bool isCustom;
  final VoidCallback onPhotoAdd;
  final void Function(UnifiedCatchRecord) onRecordTap;
  final void Function(UnifiedCatchRecord) onRecordDelete;
  final VoidCallback? onFishDelete;

  const _FishListCard({
    required this.fishName, required this.records, required this.isCustom,
    required this.onPhotoAdd, required this.onRecordTap, required this.onRecordDelete,
    this.onFishDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _fishGradient(fishName);
    final isCollected = records.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
        border: Border.all(color: isCollected ? colors[0].withOpacity(0.15) : _kBorder),
      ),
      child: Column(children: [
        if (isCollected)
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: records.length,
              itemBuilder: (_, i) {
                final r = records[i];
                return GestureDetector(
                  onTap: () => onRecordTap(r),
                  child: Container(
                    width: 200, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(fit: StackFit.expand, children: [
                        r.hasPhoto
                            ? Image.file(File(r.imagePath!), fit: BoxFit.cover,
                                errorBuilder: (_,__,___) => _FishHeroBg(fishName: fishName, record: r))
                            : _FishHeroBg(fishName: fishName, record: r),
                        Positioned(top: 6, left: 6,
                          child: GestureDetector(
                            onTap: () => onRecordDelete(r),
                            child: Container(width: 26, height: 26,
                              decoration: BoxDecoration(color: _kRed, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                        Positioned(bottom: 6, left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: Text(_shortDate(r.catchTime),
                                style: const TextStyle(color: Colors.white, fontSize: 9)))),
                      ]),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            height: 100, width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFECF0F4), const Color(0xFFDDE3EA)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Opacity(opacity: 0.2, child: Text(_kFishEmoji[fishName] ?? '🐟',
                  style: const TextStyle(fontSize: 42))),
              const SizedBox(width: 12),
              Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fishName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kNavy)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                  child: Text('미수집', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
              ]),
            ]),
          ),
        // 하단
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            // 어종명
            if (isCollected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(12)),
                child: Text(fishName, style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Text('${records.length}건',
                  style: TextStyle(fontSize: 12, color: colors[0], fontWeight: FontWeight.w600)),
            ] else
              Text(fishName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kNavy)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add_photo_alternate_outlined, color: _kBlue, size: 20),
                onPressed: onPhotoAdd, tooltip: '기록 추가', constraints: const BoxConstraints()),
            if (onFishDelete != null)
              IconButton(icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                  onPressed: onFishDelete, tooltip: '어종 삭제', constraints: const BoxConstraints()),
          ]),
        ),
      ]),
    );
  }

  String _shortDate(DateTime dt) {
    final d = DateTime.now().difference(dt).inDays;
    if (d == 0) return '오늘';
    if (d == 1) return '어제';
    if (d < 7) return '$d일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 갤러리 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GalleryCard extends StatelessWidget {
  final UnifiedCatchRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPost;

  const _GalleryCard({required this.record, required this.onTap,
      required this.onDelete, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(fit: StackFit.expand, children: [
              record.hasPhoto
                  ? Image.file(File(record.imagePath!), fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => _FishHeroBg(fishName: record.fishName, record: record))
                  : _FishHeroBg(fishName: record.fishName, record: record),
              // 삭제
              Positioned(top: 6, left: 6,
                child: GestureDetector(onTap: onDelete,
                  child: Container(width: 26, height: 26,
                    decoration: BoxDecoration(color: _kRed, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 13)))),
              // 글 만들기
              Positioned(top: 6, right: 6,
                child: GestureDetector(onTap: onPost,
                  child: Container(width: 26, height: 26,
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.article_outlined, color: Colors.white, size: 13)))),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_shortDate(record.catchTime),
                  style: const TextStyle(fontSize: 10, color: _kSub)),
              if (record.lengthCm != null || record.weightG != null)
                Text(
                  [if (record.lengthCm != null) '${record.lengthCm!.toStringAsFixed(1)}cm',
                   if (record.weightG != null) record.weightG! >= 1000
                       ? '${(record.weightG!/1000).toStringAsFixed(1)}kg'
                       : '${record.weightG!.toStringAsFixed(0)}g'].join(' · '),
                  style: const TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    final d = DateTime.now().difference(dt).inDays;
    if (d == 0) return '오늘'; if (d == 1) return '어제';
    if (d < 7) return '$d일 전'; return '${dt.month}/${dt.day}';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공통 위젯들
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggleBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: active ? Colors.white : _kSub),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
  final String? suffix;
  final int maxLines;
  const _TextField({required this.ctrl, required this.label, required this.hint,
      required this.icon, this.isNumber = false, this.suffix, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: _kBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        prefixIcon: Icon(icon, color: _kBlue, size: 18),
        suffixText: suffix, suffixStyle: const TextStyle(color: _kSub)),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 장비 추천 페이지
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GearShopScreen extends StatelessWidget {
  const GearShopScreen({super.key});

  Future<void> _launchURL(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('장비 추천', style: TextStyle(fontWeight: FontWeight.w900, color: _kNavy)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kNavy, Color(0xFF1B4F72)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.25), blurRadius: 12, offset: const Offset(0,4))]),
          child: const Row(children: [
            Text('🎣', style: TextStyle(fontSize: 36)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('낚시 입문 필수 장비', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('처음 시작하는 분들을 위한 기본 세트.\n탭하면 쿠팡에서 검색돼요.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        ...kCommonGear.map((gear) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (gear['color'] as Color).withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,3))]),
          child: InkWell(
            onTap: () => _launchURL(gear['url']),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: (gear['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(gear['icon'], style: const TextStyle(fontSize: 28))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(gear['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kNavy)),
                  const SizedBox(height: 3),
                  Text(gear['description'], style: const TextStyle(fontSize: 12, color: _kSub, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.shopping_cart_outlined, size: 12, color: gear['color'] as Color),
                    const SizedBox(width: 4),
                    Text('쿠팡에서 보기', style: TextStyle(fontSize: 11, color: gear['color'] as Color, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 2),
                    Icon(Icons.open_in_new, size: 11, color: gear['color'] as Color),
                  ]),
                ])),
              ]),
            ),
          ),
        )),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('본 앱은 판매처와 제휴 관계가 없으며, 쿠팡 검색 결과로 안내해드립니다.',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.5))),
          ]),
        ),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _InfoTile({required this.icon, required this.label, required this.value,
      this.iconColor = _kBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}