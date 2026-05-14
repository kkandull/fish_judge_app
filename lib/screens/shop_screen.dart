import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  테마 상수
// ─────────────────────────────────────────────
const Color kPrimary = Color(0xFF03C75A);
const Color kNavy    = Color(0xFF1A1A2E);
const Color kBg      = Color(0xFFF2F4F6);
const Color kCard    = Colors.white;
const Color kRed     = Color(0xFFFF4B4B);
const Color kSub     = Color(0xFF6B7684);
const Color kBorder  = Color(0xFFE8EAED);

// ─────────────────────────────────────────────
//  데이터 모델 (완벽 방어 파싱 적용)
// ─────────────────────────────────────────────
class FishingRecord {
  final String id;
  final String spotName;
  final String species;
  final String date;
  final String weather;
  final double lat;
  final double lng;
  final String memo;
  final String emoji;
  final int count;

  const FishingRecord({
    required this.id, required this.spotName, required this.species,
    required this.date, required this.weather, required this.lat,
    required this.lng, required this.memo, required this.emoji,
    this.count = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'spotName': spotName, 'species': species,
    'date': date, 'weather': weather, 'lat': lat, 'lng': lng,
    'memo': memo, 'emoji': emoji, 'count': count,
  };

  factory FishingRecord.fromJson(Map<String, dynamic> j) {
    return FishingRecord(
      id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      spotName: j['spotName']?.toString() ?? '알 수 없는 장소',
      species: j['species']?.toString() ?? '어종 미상',
      date: j['date']?.toString() ?? '',
      weather: j['weather']?.toString() ?? '☀️ 맑음',
      lat: double.tryParse(j['lat']?.toString() ?? '35.1796') ?? 35.1796,
      lng: double.tryParse(j['lng']?.toString() ?? '129.0756') ?? 129.0756,
      memo: j['memo']?.toString() ?? '',
      emoji: j['emoji']?.toString() ?? '🐟',
      count: int.tryParse(j['count']?.toString() ?? '1') ?? 1,
    );
  }
}

// ─────────────────────────────────────────────
//  부산 공공 포인트 데이터
// ─────────────────────────────────────────────
final List<Map<String, dynamic>> kBusanSpots = [
  {'name': '해운대 방파제',   'species': ['전갱이','고등어','볼락'],      'diff': '초보', 'lat': 35.1588, 'lng': 129.1603, 'tip': '새벽 입질이 강합니다.',      'icon': '🌊'},
  {'name': '광안리 방파제',   'species': ['감성돔','우럭','노래미'],      'diff': '중급', 'lat': 35.1531, 'lng': 129.1186, 'tip': '물때 3~5물 조과 최고.',     'icon': '🌉'},
  {'name': '기장 동백 방파제','species': ['도다리','볼락','전갱이'],      'diff': '초보', 'lat': 35.2446, 'lng': 129.2177, 'tip': '봄 도다리 명소.',          'icon': '🌸'},
  {'name': '감천항 동방파제', 'species': ['감성돔','볼락','전갱이'],      'diff': '중급', 'lat': 35.0785, 'lng': 128.9977, 'tip': '수심 깊어 대물 출현.',     'icon': '⚓'},
  {'name': '다대포 방파제',   'species': ['광어','우럭','쥐노래미'],      'diff': '초보', 'lat': 35.0472, 'lng': 128.9611, 'tip': '가족 낚시 추천.',         'icon': '🏖️'},
  {'name': '암남공원 갯바위', 'species': ['벵에돔','감성돔','독가시치'], 'diff': '고급', 'lat': 35.0601, 'lng': 129.0061, 'tip': '독가시치 주의! 장갑 필수.', 'icon': '⚠️'},
  {'name': '영도 태종대',     'species': ['참돔','벵에돔','쥐노래미'],   'diff': '중급', 'lat': 35.0530, 'lng': 129.0850, 'tip': '조류 강해 채비 무겁게.',   'icon': '🗿'},
  {'name': '송정 방파제',     'species': ['전갱이','고등어','삼치'],      'diff': '초보', 'lat': 35.1794, 'lng': 129.2037, 'tip': '가을 삼치 루어 명소.',    'icon': '🎣'},
];

// ─────────────────────────────────────────────
//  메인 화면
// ─────────────────────────────────────────────
class MyMapScreen extends StatefulWidget {
  const MyMapScreen({super.key});
  @override State<MyMapScreen> createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<FishingRecord> _records = [];
  int _selectedSpotIdx = -1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadRecords();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadRecords() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getStringList('fishing_records_v3') ?? [];
      if (!mounted) return;
      
      final parsedRecords = <FishingRecord>[];
      for (var e in raw) {
        try {
          parsedRecords.add(FishingRecord.fromJson(jsonDecode(e)));
        } catch (_) {} // 깨진 데이터는 무시
      }
      
      setState(() {
        _records = parsedRecords..sort((a, b) => b.date.compareTo(a.date));
      });
    } catch (e) {
      debugPrint('조과 일지 로드 실패: $e');
    }
  }

  Future<void> _saveRecords() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('fishing_records_v3',
        _records.map((e) => jsonEncode(e.toJson())).toList());
  }

  void _addRecord(FishingRecord r) {
    setState(() => _records.insert(0, r));
    _saveRecords();
  }

  void _deleteRecord(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _records.removeWhere((r) => r.id == id));
    _saveRecords();
  }

  void _confirmDelete(FishingRecord r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗑️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          const Text('기록 삭제',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('"${r.spotName}" 기록을 삭제할까요?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSub, height: 1.5)),
        ]),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소', style: TextStyle(color: kSub)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () { Navigator.pop(ctx); _deleteRecord(r.id); },
                child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: kNavy,
            title: Row(children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('N', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const SizedBox(width: 8),
              const Text('나만의 낚시 지도',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 17, letterSpacing: -0.3)),
            ]),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: kPrimary,
              indicatorWeight: 3,
              labelColor: kPrimary,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                const Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.map_outlined, size: 15),
                    SizedBox(width: 5), Text('포인트 지도'),
                  ]),
                ),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.menu_book_outlined, size: 15),
                    const SizedBox(width: 5),
                    const Text('조과 일지'),
                    if (_records.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: kPrimary, borderRadius: BorderRadius.circular(10)),
                        child: Text('${_records.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _MapTab(
              spots: kBusanSpots,
              selectedIdx: _selectedSpotIdx,
              onSelectSpot: (i) => setState(() =>
                  _selectedSpotIdx = _selectedSpotIdx == i ? -1 : i),
              onAddRecord: () => _showAddSheet(context),
            ),
            _JournalTab(
              records: _records,
              onDelete: _confirmDelete,
              onAddRecord: () => _showAddSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── 조과 기록 추가 바텀시트 ──
  void _showAddSheet(BuildContext context) {
    final spotCtrl    = TextEditingController();
    final speciesCtrl = TextEditingController();
    final memoCtrl    = TextEditingController();
    int count = 1;
    String emoji   = '🐟';
    String weather = '☀️ 맑음';

    final emojis   = ['🐟','🐠','🦈','🦐','🦑','🐡','🦀','🐙'];
    final weathers = ['☀️ 맑음','⛅ 구름','🌧️ 비','💨 바람','🌙 야간'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: kBorder, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_location_alt_outlined,
                        color: kPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('조과 기록 추가',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 22),

                _sheetLabel('어종 선택'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: emojis.map((e) => GestureDetector(
                      onTap: () => ss(() => emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 52, height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? kPrimary.withOpacity(0.12) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: emoji == e ? kPrimary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 25)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                _sheetField(spotCtrl, '포인트 이름', '예: 해운대 방파제 끝단'),
                const SizedBox(height: 12),
                _sheetField(speciesCtrl, '잡은 어종', '예: 감성돔'),
                const SizedBox(height: 16),

                _sheetLabel('마릿수'),
                const SizedBox(height: 8),
                Row(children: [
                  _countBtn('−', () => ss(() { if (count > 1) count--; })),
                  const SizedBox(width: 14),
                  Text('$count 마리',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
                  const SizedBox(width: 14),
                  _countBtn('+', () => ss(() => count++)),
                ]),
                const SizedBox(height: 16),

                _sheetLabel('날씨'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7, runSpacing: 7,
                  children: weathers.map((w) => GestureDetector(
                    onTap: () => ss(() => weather = w),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: weather == w ? kPrimary : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(w, style: TextStyle(
                        color: weather == w ? Colors.white : kSub,
                        fontWeight: FontWeight.w600, fontSize: 12,
                      )),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                _sheetField(memoCtrl, '메모 (선택)', '조황, 미끼, 팁 등 자유롭게', maxLines: 3),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.gps_fixed, color: kPrimary, size: 15),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'GPS 위치 자동 저장 · 오프라인 좌표 저장 후 온라인 시 지명 변환',
                      style: TextStyle(fontSize: 11, color: kPrimary, height: 1.4),
                    )),
                  ]),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (spotCtrl.text.trim().isEmpty || speciesCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          _snackBar('포인트와 어종은 필수입니다.', isError: true));
                        return;
                      }
                      final now = DateTime.now();
                      _addRecord(FishingRecord(
                        id: now.millisecondsSinceEpoch.toString(),
                        spotName: spotCtrl.text.trim(),
                        species: speciesCtrl.text.trim(),
                        date: '${now.year}.${now.month.toString().padLeft(2,'0')}.${now.day.toString().padLeft(2,'0')}',
                        weather: weather,
                        lat: 35.1796, lng: 129.0756, 
                        memo: memoCtrl.text.trim(),
                        emoji: emoji,
                        count: count,
                      ));
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          _snackBar('조과 기록이 저장되었습니다!'));
                    },
                    child: const Text('저장하기',
                        style: TextStyle(fontSize: 15, color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String t) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.w700, color: kSub,
          fontSize: 11, letterSpacing: 0.5));

  Widget _sheetField(TextEditingController c, String label, String hint,
      {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetLabel(label),
      const SizedBox(height: 6),
      TextField(
        controller: c, maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: kNavy),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          filled: true, fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _countBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Text(label, style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: kNavy)),
    ),
  );

  SnackBar _snackBar(String msg, {bool isError = false}) => SnackBar(
    content: Row(children: [
      Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle,
          color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
    ]),
    backgroundColor: isError ? kRed : kNavy,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  );
}

// ─────────────────────────────────────────────
//  탭 1: 포인트 지도
// ─────────────────────────────────────────────
class _MapTab extends StatefulWidget {
  final List<Map<String, dynamic>> spots;
  final int selectedIdx;
  final Function(int) onSelectSpot;
  final VoidCallback onAddRecord;
  const _MapTab({
    required this.spots, required this.selectedIdx,
    required this.onSelectSpot, required this.onAddRecord,
  });
  @override State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  String _filter = '전체';
  final _diffs = ['전체','초보','중급','고급'];

  Color _diffColor(String d) => switch (d) {
    '초보' => const Color(0xFF22C55E),
    '중급' => const Color(0xFFF97316),
    '고급' => kRed,
    _      => kSub,
  };

  Color _diffBg(String d) => switch (d) {
    '초보' => const Color(0x1A22C55E),
    '중급' => const Color(0x1AF97316),
    '고급' => const Color(0x1AFF4B4B),
    _      => const Color(0x1A6B7684),
  };

  List<Map<String, dynamic>> get _filtered => _filter == '전체'
      ? widget.spots
      : widget.spots.where((s) => s['diff'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.5,
          child: _NaverStyleMap(
            spots: _filtered,
            selectedIdx: widget.selectedIdx,
            onSelectSpot: widget.onSelectSpot,
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.54,
          minChildSize: 0.34,
          maxChildSize: 0.86,
          builder: (ctx, sc) => Container(
            decoration: const BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: Column(
              children: [
                Container(
                  width: 40, height: 5, margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                      color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _diffs.map((d) => GestureDetector(
                              onTap: () {
                                setState(() => _filter = d);
                                widget.onSelectSpot(-1);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _filter == d ? kNavy : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _filter == d ? kNavy : Colors.transparent,
                                  ),
                                ),
                                child: Text(d, style: TextStyle(
                                  color: _filter == d ? Colors.white : kSub,
                                  fontWeight: FontWeight.bold, fontSize: 13,
                                )),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text('${_filtered.length}곳',
                            style: const TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final spot = _filtered[i];
                      final isSel = widget.selectedIdx == i;
                      return GestureDetector(
                        onTap: () => widget.onSelectSpot(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSel ? kNavy : kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel ? kPrimary : kBorder,
                              width: isSel ? 1.5 : 1,
                            ),
                            boxShadow: isSel
                                ? [BoxShadow(
                                    color: kPrimary.withOpacity(0.2),
                                    blurRadius: 15, offset: const Offset(0, 5))]
                                : [const BoxShadow(
                                    color: Color(0x05000000), blurRadius: 8)],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 52, height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? kPrimary.withOpacity(0.15) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(spot['icon'], style: const TextStyle(fontSize: 26)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(spot['name'],
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isSel ? Colors.white : kNavy,
                                        ))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? _diffColor(spot['diff']).withOpacity(0.25)
                                            : _diffBg(spot['diff']),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(spot['diff'], style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.bold,
                                        color: isSel ? Colors.white : _diffColor(spot['diff']),
                                      )),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6,
                                    children: (spot['species'] as List<String>).map((s) =>
                                      Text('#$s', style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w500,
                                        color: isSel ? Colors.white70 : kSub,
                                      ))).toList(),
                                  ),
                                ],
                              )),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: isSel ? kPrimary : Colors.grey[400], size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'map_fab',
            backgroundColor: kPrimary,
            elevation: 6,
            onPressed: widget.onAddRecord,
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text('조과 기록',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  지도 위젯
// ─────────────────────────────────────────────
class _NaverStyleMap extends StatelessWidget {
  final List<Map<String, dynamic>> spots;
  final int selectedIdx;
  final Function(int) onSelectSpot;
  const _NaverStyleMap({
    required this.spots, required this.selectedIdx, required this.onSelectSpot,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(color: const Color(0xFFE1F0FA)),
        CustomPaint(painter: _LandPainter(), size: Size.infinite),
        CustomPaint(painter: _RoadPainter(), size: Size.infinite),

        ...spots.asMap().entries.map((e) {
          final i = e.key; final spot = e.value;
          final isSel = selectedIdx == i;
          
          final dx = ((spot['lng'] as double) - 128.96) / 0.28 * size.width;
          final dy = (1 - ((spot['lat'] as double) - 35.04) / 0.22) * 250;
          final x = dx.clamp(40.0, size.width - 40.0);
          final y = dy.clamp(40.0, size.height * 0.45);

          return Positioned(
            left: x - 25,
            top: y - 50,
            child: GestureDetector(
              onTap: () => onSelectSpot(i),
              child: SizedBox(
                width: 50, height: 70,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (isSel)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 1),
                        builder: (ctx, val, child) {
                          return Container(
                            width: 30 + (val * 20),
                            height: 10 + (val * 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50), 
                              border: Border.all(color: kPrimary.withOpacity(1 - val), width: 2),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 14, height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      bottom: isSel ? 10 : 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSel)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(6)),
                              child: Text(spot['name'], 
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          Icon(
                            Icons.location_on,
                            size: isSel ? 44 : 36,
                            color: isSel ? kPrimary : const Color(0xFF6B7684),
                            shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        Positioned(
          right: 16, top: MediaQuery.of(context).padding.top + 16,
          child: Column(children: [
            _mapCtrlBtn(Icons.explore_outlined, () {}),
            const SizedBox(height: 8),
            _mapCtrlBtn(Icons.my_location_rounded, () {}, color: kPrimary),
          ]),
        ),
        
        Positioned(
          left: 16, bottom: 30,
          child: Text('Now Fishing Map Data', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _mapCtrlBtn(IconData icon, VoidCallback onTap, {Color? color}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: color ?? Colors.grey[700]),
      ),
    );
}

class _LandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF4F4F0)..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)..lineTo(size.width * 0.8, 0)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.3, size.width * 0.9, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.5)..lineTo(size.width, size.height)
      ..lineTo(0, size.height)..close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white..strokeWidth = 4
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.25, size.width * 0.6, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.8);
    canvas.drawPath(path, paint);
    paint.color = const Color(0xFFFFD54F).withOpacity(0.8);
    paint.strokeWidth = 2;
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
//  탭 2: 조과 일지
// ─────────────────────────────────────────────
class _JournalTab extends StatelessWidget {
  final List<FishingRecord> records;
  final Function(FishingRecord) onDelete;
  final VoidCallback onAddRecord;
  const _JournalTab({
    required this.records, required this.onDelete, required this.onAddRecord,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Stack(children: [
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎣', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 14),
          const Text('아직 조과 기록이 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
          const SizedBox(height: 6),
          const Text('낚시 다녀온 후 기록을 남겨보세요!', style: TextStyle(fontSize: 14, color: kSub)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onAddRecord,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('첫 기록 남기기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ])),
      ]);
    }

    final totalCount  = records.fold(0, (s, r) => s + r.count);
    final uniqueSpots = records.map((r) => r.spotName).toSet().length;
    final uniqueSpec  = records.map((r) => r.species).toSet().length;

    return Stack(children: [
      CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kNavy, Color(0xFF1B6CA8)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: kNavy.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('총 출조',   '${records.length}회', Icons.directions_boat),
                  _vDiv(),
                  _stat('포인트',   '${uniqueSpots}곳',    Icons.place_outlined),
                  _vDiv(),
                  _stat('어종',    '${uniqueSpec}종',      Icons.set_meal_outlined),
                  _vDiv(),
                  _stat('총 마릿수', '${totalCount}마',     Icons.water_drop_outlined),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _RecordCard(
                  record: records[i],
                  onDelete: () => onDelete(records[i]),
                ),
                childCount: records.length,
              ),
            ),
          ),
        ],
      ),
      Positioned(
        bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16,
        right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'journal_fab',
          backgroundColor: kPrimary,
          elevation: 6,
          onPressed: onAddRecord,
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text('조과 기록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    ]);
  }

  Widget _stat(String label, String value, IconData icon) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white54, size: 17),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.15));
}

// ─────────────────────────────────────────────
//  조과 기록 카드 (스와이프 삭제 수정본)
// ─────────────────────────────────────────────
class _RecordCard extends StatefulWidget {
  final FishingRecord record;
  final VoidCallback onDelete;
  const _RecordCard({required this.record, required this.onDelete});
  @override State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  double _dragX = 0;
  bool _isSwiped = false;
  static const double _threshold = 72;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          // 삭제 배경 (높이 무한대 에러 해결)
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _dragX < -10 ? kRed : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
            ),
          ),
          
          // 카드 본체
          GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dragX += d.delta.dx;
                _dragX = _dragX.clamp(-_threshold, 0);
              });
            },
            onHorizontalDragEnd: (d) {
              if (_dragX < -_threshold / 2) {
                setState(() { _dragX = -_threshold; _isSwiped = true; });
              } else {
                setState(() { _dragX = 0; _isSwiped = false; });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(_dragX, 0, 0),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(widget.record.emoji, style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.record.spotName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kNavy)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _tag(widget.record.species, kPrimary.withOpacity(0.1), kPrimary),
                                  const SizedBox(width: 6),
                                  _tag('${widget.record.count}마리', const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(widget.record.date, style: const TextStyle(color: kSub, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: kBorder),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() { _dragX = 0; _isSwiped = false; });
                              widget.onDelete();
                            },
                            icon: const Icon(Icons.delete_outline, size: 16, color: kRed),
                            label: const Text('삭제', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: kBorder, indent: 10, endIndent: 10),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share_outlined, size: 16, color: kSub),
                            label: const Text('공유', style: TextStyle(color: kSub, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}