import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/unified_catch_record.dart';
import '../services/catch_record_repository.dart';
import '../widgets/unified_catch_form.dart';
import 'catch_record_detail_screen.dart'; // ⭐ 상세 화면

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const Color kPrimary = Color(0xFF03C75A);
const Color kNavy    = Color(0xFF1A1A2E);
const Color kBg      = Color(0xFFF2F4F6);
const Color kCard    = Colors.white;
const Color kRed     = Color(0xFFFF4B4B);
const Color kSub     = Color(0xFF6B7684);
const Color kBorder  = Color(0xFFE8EAED);
const Color kOrange  = Color(0xFFF97316);
const Color kBlue    = Color(0xFF1976D2);

enum MarkerKind { official, userSpot }

class MapMarker {
  final String id;
  final String name;
  final List<String> species;
  final String diff;
  final double lat;
  final double lng;
  final String tip;
  final String icon;
  final MarkerKind kind;
  final UnifiedCatchRecord? record;

  const MapMarker({
    required this.id,
    required this.name,
    required this.species,
    required this.diff,
    required this.lat,
    required this.lng,
    required this.tip,
    required this.icon,
    required this.kind,
    this.record,
  });

  bool get isUser => kind == MarkerKind.userSpot;
  LatLng get latLng => LatLng(lat, lng);
}

final List<MapMarker> kBusanSpots = [
  const MapMarker(id:'official_haeundae',   name:'해운대 방파제',    species:['전갱이','고등어','볼락'],         diff:'초보', lat:35.1588, lng:129.1603, tip:'새벽 입질이 강합니다.',            icon:'🌊', kind:MarkerKind.official),
  const MapMarker(id:'official_gwangan',    name:'광안리 방파제',    species:['감성돔','우럭','노래미'],         diff:'중급', lat:35.1531, lng:129.1186, tip:'물때 3~5물 조과 최고.',            icon:'🌉', kind:MarkerKind.official),
  const MapMarker(id:'official_gijang',     name:'기장 동백 방파제', species:['도다리','볼락','전갱이'],         diff:'초보', lat:35.2446, lng:129.2177, tip:'봄 도다리 명소.',                  icon:'🌸', kind:MarkerKind.official),
  const MapMarker(id:'official_gamcheon',   name:'감천항 동방파제',  species:['감성돔','볼락','전갱이'],         diff:'중급', lat:35.0785, lng:128.9977, tip:'수심 깊어 대물 출현.',             icon:'⚓', kind:MarkerKind.official),
  const MapMarker(id:'official_dadaepo',    name:'다대포 방파제',    species:['광어','우럭','쥐노래미'],         diff:'초보', lat:35.0472, lng:128.9611, tip:'가족 낚시 추천.',                  icon:'🏖️', kind:MarkerKind.official),
  const MapMarker(id:'official_amnam',      name:'암남공원 갯바위',  species:['벵에돔','감성돔','독가시치'],     diff:'고급', lat:35.0601, lng:129.0061, tip:'독가시치 주의! 장갑 필수.',        icon:'⚠️', kind:MarkerKind.official),
  const MapMarker(id:'official_taejongdae', name:'영도 태종대',      species:['참돔','벵에돔','쥐노래미'],       diff:'중급', lat:35.0530, lng:129.0850, tip:'조류 강해 채비 무겁게.',            icon:'🗿', kind:MarkerKind.official),
  const MapMarker(id:'official_songjeong',  name:'송정 방파제',      species:['전갱이','고등어','삼치'],         diff:'초보', lat:35.1794, lng:129.2037, tip:'가을 삼치 루어 명소.',             icon:'🎣', kind:MarkerKind.official),
];

const LatLng kBusanCenter = LatLng(35.1531, 129.1186);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Root
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class MyMapScreen extends StatefulWidget {
  const MyMapScreen({super.key});
  @override
  State<MyMapScreen> createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final repo = CatchRecordRepository.instance;
  StreamSubscription? _changeSub;

  List<UnifiedCatchRecord> _records = [];
  List<MapMarker> _userSpots = [];
  MapMarker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadRecords();
    _changeSub = repo.changes.listen((_) => _loadRecords());
  }

  @override
  void dispose() {
    _tab.dispose();
    _changeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final all = await repo.getAll();
    if (!mounted) return;

    final spots = <MapMarker>[];
    final seenIds = <String>{};
    final officialNames = kBusanSpots.map((s) => s.name).toSet();

    for (final r in all) {
      if (r.latitude == null || r.longitude == null) continue;
      final name = r.spotName ?? r.fishName;
      if (officialNames.contains(name)) continue;
      if (!seenIds.add(r.id)) continue;

      spots.add(MapMarker(
        id: r.id,
        name: name,
        species: [r.fishName],
        diff: '사용자',
        lat: r.latitude!,
        lng: r.longitude!,
        tip: r.memo.isEmpty ? '내가 직접 추가한 포인트' : r.memo,
        icon: r.emoji,
        kind: MarkerKind.userSpot,
        record: r,
      ));
    }

    setState(() {
      _records = all;
      _userSpots = spots;
      if (_selectedMarker != null) {
        final stillExists = [...kBusanSpots, ..._userSpots].any((m) => m.id == _selectedMarker!.id);
        if (!stillExists) _selectedMarker = null;
      }
    });
  }

  Future<void> _deleteRecord(String id) async {
    HapticFeedback.mediumImpact();
    await repo.delete(id);
  }

  void _confirmDeleteRecord(UnifiedCatchRecord r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const Text('기록 삭제', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '"${r.spotName ?? r.fishName}" 기록을 삭제할까요?\n도감과 지도에서 함께 사라집니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kSub, height: 1.5),
          ),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteRecord(r.id);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ⭐ 상세 화면으로 이동
  void _openDetail(UnifiedCatchRecord r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CatchRecordDetailScreen(record: r)),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showUnifiedCatchForm(context, createdFrom: 'map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kNavy,
        title: const Text(
          '나만의 낚시 지도',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.3),
        ),
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
                Icon(Icons.map_outlined, size: 15), SizedBox(width: 5), Text('포인트 지도'),
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
                    decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_records.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MapTab(
            officialSpots: kBusanSpots,
            userSpots: _userSpots,
            selectedMarker: _selectedMarker,
            onSelectMarker: (m) => setState(() => _selectedMarker = (_selectedMarker?.id == m?.id) ? null : m),
            onDeleteUserSpot: (m) { if (m.record != null) _confirmDeleteRecord(m.record!); },
            onOpenDetail: (m) { if (m.record != null) _openDetail(m.record!); },
            onAddRecord: () => _showAddSheet(context),
          ),
          _JournalTab(
            records: _records,
            onDelete: _confirmDeleteRecord,
            onOpenDetail: _openDetail,
            onAddRecord: () => _showAddSheet(context),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 지도 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MapTab extends StatefulWidget {
  final List<MapMarker> officialSpots;
  final List<MapMarker> userSpots;
  final MapMarker? selectedMarker;
  final Function(MapMarker?) onSelectMarker;
  final Function(MapMarker) onDeleteUserSpot;
  final Function(MapMarker) onOpenDetail;  // ⭐ 신규
  final VoidCallback onAddRecord;

  const _MapTab({
    required this.officialSpots,
    required this.userSpots,
    required this.selectedMarker,
    required this.onSelectMarker,
    required this.onDeleteUserSpot,
    required this.onOpenDetail,
    required this.onAddRecord,
  });

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapEventSub;

  String _filter = '전체';
  final _diffs = ['전체', '초보', '중급', '고급', '사용자'];
  bool _offline = false;
  double _currentRotation = 0;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _mapEventSub = _mapController.mapEventStream.listen((e) {
      if (!mounted) return;
      try {
        final rot = _mapController.camera.rotation;
        if ((rot - _currentRotation).abs() > 0.5) setState(() => _currentRotation = rot);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  List<MapMarker> get _allSpots => [...widget.officialSpots, ...widget.userSpots];
  List<MapMarker> get _filtered => _filter == '전체' ? _allSpots : _allSpots.where((s) => s.diff == _filter).toList();

  Color _diffColor(String d) => switch (d) {
    '초보' => const Color(0xFF22C55E), '중급' => const Color(0xFFF97316),
    '고급' => kRed, '사용자' => kOrange, _ => kSub,
  };
  Color _diffBg(String d) => switch (d) {
    '초보' => const Color(0x1A22C55E), '중급' => const Color(0x1AF97316),
    '고급' => const Color(0x1AFF4B4B), '사용자' => const Color(0x1AF97316), _ => const Color(0x1A6B7684),
  };

  void _moveToLatLng(LatLng pos, {double? zoom}) {
    try { _mapController.move(pos, zoom ?? _mapController.camera.zoom); } catch (_) {}
  }
  void _zoomIn() { try { final z = _mapController.camera.zoom; if (z < 18) _mapController.move(_mapController.camera.center, z+1); } catch(_) {} }
  void _zoomOut() { try { final z = _mapController.camera.zoom; if (z > 5) _mapController.move(_mapController.camera.center, z-1); } catch(_) {} }
  void _resetRotation() { try { _mapController.rotate(0); } catch(_) {} }

  Future<void> _goToCurrentLocation() async {
    if (_gpsLoading) return;
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) { _showSnack('위치 권한이 필요합니다.', isError: true); _moveToLatLng(kBusanCenter, zoom: 12); }
        return;
      }
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) { if (mounted) { _showSnack('GPS가 꺼져있습니다.', isError: true); _moveToLatLng(kBusanCenter, zoom: 12); } return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 8));
      if (!mounted) return;
      _moveToLatLng(LatLng(pos.latitude, pos.longitude), zoom: 15);
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) { _showSnack('위치를 가져올 수 없어요.', isError: true); _moveToLatLng(kBusanCenter, zoom: 12); }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
      backgroundColor: isError ? kRed : kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  Marker _buildMarker(MapMarker m) {
    final isSel = widget.selectedMarker?.id == m.id;
    final size = isSel ? 56.0 : 48.0;
    return Marker(
      point: m.latLng,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () { widget.onSelectMarker(m); _moveToLatLng(m.latLng); },
        child: Stack(alignment: Alignment.center, children: [
          Container(width: size, height: size,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), shape: BoxShape.circle)),
          Container(
            width: size-8, height: size-8,
            decoration: BoxDecoration(
              color: isSel ? kNavy : (m.isUser ? kOrange : kPrimary),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: (m.isUser ? kOrange : kPrimary).withOpacity(0.4), blurRadius: 8, spreadRadius: isSel ? 2 : 0)],
            ),
            alignment: Alignment.center,
            child: m.isUser
                ? Text(m.icon, style: const TextStyle(fontSize: 20))
                : const Icon(Icons.location_on, color: Colors.white, size: 22),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fullHeight = constraints.maxHeight;
      final markers = _filtered.map(_buildMarker).toList();

      return SizedBox(
        width: constraints.maxWidth, height: fullHeight,
        child: Stack(children: [
          Positioned.fill(
            child: ClipRect(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: kBusanCenter, initialZoom: 11.5, minZoom: 6, maxZoom: 18,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, __) { if (widget.selectedMarker != null) widget.onSelectMarker(null); },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.vworld.kr/req/wmts/1.0.0/073BDFC8-1AD7-3E0A-9FDF-FD273FAD78D5/Base/{z}/{y}/{x}.png',
                    errorTileCallback: (tile, error, stackTrace) {
                      if (mounted && !_offline) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _offline = true); });
                    },
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),

          Positioned(left: 8, bottom: (fullHeight * 0.15) + 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: Colors.white.withOpacity(0.85),
              child: const Text('© OpenStreetMap, © CARTO', style: TextStyle(fontSize: 8, color: Colors.black87)),
            ),
          ),

          if (_offline)
            Positioned(top: 16, left: 16, right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16), SizedBox(width: 8),
                  Flexible(child: Text('인터넷 연결을 확인해주세요', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                ]),
              ),
            ),

          Positioned(top: 16, right: 16,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_currentRotation.abs() > 1) ...[
                _mapCtrlBtn(Icons.explore, _resetRotation, color: kNavy),
                const SizedBox(height: 8),
              ],
              _mapCtrlBtn(Icons.add, _zoomIn),
              const SizedBox(height: 8),
              _mapCtrlBtn(Icons.remove, _zoomOut),
              const SizedBox(height: 8),
              _mapCtrlBtn(_gpsLoading ? Icons.hourglass_top : Icons.my_location_rounded,
                  _goToCurrentLocation, color: kPrimary, loading: _gpsLoading),
            ]),
          ),

          // ⭐ 팝업 — 탭 시 상세 화면으로
          if (widget.selectedMarker != null)
            Positioned(top: 16, left: 16, right: 80,
              child: _InfoPopup(
                marker: widget.selectedMarker!,
                onClose: () => widget.onSelectMarker(null),
                onDelete: () => widget.onDeleteUserSpot(widget.selectedMarker!),
                onOpenDetail: () => widget.onOpenDetail(widget.selectedMarker!),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: 0.38, minChildSize: 0.15, maxChildSize: 0.86,
            builder: (ctx, sc) => Container(
              decoration: const BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: CustomScrollView(controller: sc, slivers: [
                SliverToBoxAdapter(child: Center(
                  child: Container(width: 40, height: 5, margin: const EdgeInsets.only(top: 14, bottom: 8),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Row(children: [
                    Expanded(child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _diffs.map((d) {
                        final isActive = _filter == d;
                        return GestureDetector(
                          onTap: () { setState(() => _filter = d); widget.onSelectMarker(null); },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? (d == '사용자' ? kOrange : kNavy) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(d, style: TextStyle(color: isActive ? Colors.white : kSub, fontWeight: FontWeight.bold, fontSize: 13)),
                              if (d == '사용자' && widget.userSpots.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white24 : kOrange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${widget.userSpots.length}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.white : kOrange)),
                                ),
                              ],
                            ]),
                          ),
                        );
                      }).toList()),
                    )),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${_filtered.length}곳',
                        style: const TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                )),
                if (_filtered.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_filter == '사용자' ? '' : '🎣', style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(_filter == '사용자' ? '아직 추가한 포인트가 없어요' : '$_filter 난이도 포인트가 없어요',
                        style: const TextStyle(color: kSub, fontSize: 13)),
                    ]),
                  ))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final spot = _filtered[i];
                        final isSel = widget.selectedMarker?.id == spot.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SpotListCard(
                            spot: spot, isSelected: isSel,
                            diffColor: _diffColor(spot.diff), diffBg: _diffBg(spot.diff),
                            onTap: () { widget.onSelectMarker(spot); _moveToLatLng(spot.latLng, zoom: 15); },
                          ),
                        );
                      },
                      childCount: _filtered.length,
                    )),
                  ),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _mapCtrlBtn(IconData icon, VoidCallback onTap, {Color? color, bool loading = false}) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(21), elevation: 4, shadowColor: Colors.black26,
      child: InkWell(borderRadius: BorderRadius.circular(21), onTap: loading ? null : onTap,
        child: SizedBox(width: 42, height: 42, child: Center(
          child: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: kPrimary))
              : Icon(icon, size: 22, color: color ?? Colors.grey[700]),
        )),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// InfoPopup — ⭐ 탭 시 상세 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _InfoPopup extends StatelessWidget {
  final MapMarker marker;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;  // ⭐

  const _InfoPopup({
    required this.marker,
    required this.onClose,
    required this.onDelete,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final r = marker.record;
    final hasPhoto = r?.imagePath != null;

    return GestureDetector(
      onTap: marker.isUser ? onOpenDetail : null,  // ⭐ 사용자 마커는 탭으로 상세
      child: SizedBox(
        height: 100,
        child: Material(
          color: Colors.white, elevation: 8,
          borderRadius: BorderRadius.circular(16), shadowColor: Colors.black38,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(children: [
              SizedBox(width: 80, height: 100,
                child: hasPhoto
                    ? Image.file(File(r!.imagePath!), fit: BoxFit.cover,
                        errorBuilder: (_,__,___) => _iconBlock(marker))
                    : _iconBlock(marker),
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Expanded(child: Text(marker.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kNavy))),
                      // ⭐ 상세보기 힌트 (사용자 마커)
                      if (marker.isUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Text('상세', style: TextStyle(fontSize: 10, color: kBlue, fontWeight: FontWeight.bold)),
                        )
                      else
                        GestureDetector(
                          onTap: onClose,
                          child: Container(width: 22, height: 22, alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: kSub)),
                        ),
                    ]),
                    SizedBox(height: 18,
                      child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.zero,
                        children: marker.species.take(3).map((s) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (marker.isUser ? kOrange : kPrimary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('#$s', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: marker.isUser ? kOrange : kPrimary)),
                        )).toList(),
                      ),
                    ),
                    Row(children: [
                      Expanded(child: r != null
                          ? Row(children: [
                              const Icon(Icons.access_time, size: 10, color: kSub), const SizedBox(width: 3),
                              Flexible(child: Text(
                                r.count > 1 ? '${r.dateStr} · ${r.count}마리' : r.dateStr,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: kSub),
                              )),
                            ])
                          : Text(marker.tip, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: kSub, height: 1.3)),
                      ),
                      if (marker.isUser) ...[
                        const SizedBox(width: 4),
                        // 닫기
                        GestureDetector(
                          onTap: onClose,
                          child: Container(width: 22, height: 22, alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 13, color: kSub)),
                        ),
                        const SizedBox(width: 4),
                        // 삭제
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_outline, size: 12, color: kRed), SizedBox(width: 3),
                              Text('삭제', style: TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _iconBlock(MapMarker m) => Container(
    width: 80, height: 100,
    color: (m.isUser ? kOrange : kPrimary).withOpacity(0.1),
    alignment: Alignment.center,
    child: Text(m.icon, style: const TextStyle(fontSize: 36)),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 포인트 리스트 카드 (기존 그대로)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _SpotListCard extends StatelessWidget {
  final MapMarker spot;
  final bool isSelected;
  final Color diffColor;
  final Color diffBg;
  final VoidCallback onTap;

  const _SpotListCard({
    required this.spot, required this.isSelected,
    required this.diffColor, required this.diffBg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kNavy : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? (spot.isUser ? kOrange : kPrimary) : kBorder, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: (spot.isUser ? kOrange : kPrimary).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))]
              : [const BoxShadow(color: Color(0x05000000), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(width: 52, height: 52, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? (spot.isUser ? kOrange.withOpacity(0.2) : kPrimary.withOpacity(0.15)) : Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(spot.icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(spot.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isSelected ? Colors.white : kNavy))),
              const SizedBox(width: 8),
              spot.isUser
                  ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isSelected ? kOrange.withOpacity(0.3) : kOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                      child: const Text('내 포인트', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kOrange)))
                  : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isSelected ? diffColor.withOpacity(0.25) : diffBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(spot.diff, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : diffColor))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: spot.species.map((s) => Text('#$s',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : kSub))).toList()),
            const SizedBox(height: 4),
            Text(spot.tip, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isSelected ? Colors.white38 : Colors.grey[400])),
          ])),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 조과 일지 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _JournalTab extends StatelessWidget {
  final List<UnifiedCatchRecord> records;
  final Function(UnifiedCatchRecord) onDelete;
  final Function(UnifiedCatchRecord) onOpenDetail;  // ⭐
  final VoidCallback onAddRecord;

  const _JournalTab({
    required this.records,
    required this.onDelete,
    required this.onOpenDetail,
    required this.onAddRecord,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Stack(children: [
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          const Text('🎣', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 14),
          const Text('아직 조과 기록이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
          const SizedBox(height: 6),
          const Text('낚시 다녀온 후 기록을 남겨보세요!', style: TextStyle(fontSize: 14, color: kSub)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: onAddRecord,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('첫 기록 남기기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ])),
      ]);
    }

    final totalCount  = records.fold<int>(0, (s, r) => s + r.count);
    final uniqueSpots = records.where((r) => r.spotName != null).map((r) => r.spotName!).toSet().length;
    final uniqueSpec  = records.map((r) => r.fishName).toSet().length;
    final spotAdded   = records.where((r) => r.latitude != null).length;

    return Stack(children: [
      CustomScrollView(slivers: [
        // 통계 헤더
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNavy, Color(0xFF1B6CA8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: kNavy.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('총 출조', '${records.length}회', Icons.directions_boat),
            _vDiv(),
            _stat('포인트', '${uniqueSpots}곳', Icons.place_outlined),
            _vDiv(),
            _stat('어종', '${uniqueSpec}종', Icons.set_meal_outlined),
            _vDiv(),
            _stat('총 마릿수', '${totalCount}마', Icons.water_drop_outlined),
          ]),
        )),
        if (spotAdded > 0)
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOrange.withOpacity(0.25)),
            ),
            child: Row(children: [
              const SizedBox(width: 8),
              Expanded(child: Text(
                '위치 정보가 있는 기록 $spotAdded개가 포인트 지도에 자동 등록됐어요',
                style: TextStyle(fontSize: 12, color: kOrange.withOpacity(0.9), fontWeight: FontWeight.w500),
              )),
            ]),
          )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _RecordCard(
              record: records[i],
              onDelete: () => onDelete(records[i]),
              onOpenDetail: () => onOpenDetail(records[i]),  // ⭐
            ),
            childCount: records.length,
          )),
        ),
      ]),
      // FAB
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

  Widget _stat(String label, String value, IconData icon) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white54, size: 17), const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.15));
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 조과 기록 카드 — ⭐ 탭 → 상세 / 삭제 확인
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecordCard extends StatefulWidget {
  final UnifiedCatchRecord record;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;  // ⭐

  const _RecordCard({
    required this.record,
    required this.onDelete,
    required this.onOpenDetail,
  });

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  double _dragX = 0;
  static const double _threshold = 72;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final hasLocation = r.latitude != null && r.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(children: [
        // 스와이프 삭제 배경
        Positioned.fill(child: Container(
          padding: const EdgeInsets.only(right: 24),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: _dragX < -10 ? kRed : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
        )),
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() => _dragX = (_dragX + d.delta.dx).clamp(-_threshold, 0)),
          onHorizontalDragEnd: (d) {
            if (_dragX < -_threshold / 2) {
              setState(() => _dragX = -_threshold);
            } else {
              setState(() => _dragX = 0);
            }
          },
          // ⭐ 탭 → 상세 화면
          onTap: () {
            if (_dragX < -10) {
              setState(() => _dragX = 0); // 스와이프 닫기
            } else {
              widget.onOpenDetail();
            }
          },
          child: Transform.translate(
            offset: Offset(_dragX, 0),
            child: Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    // 사진 or 이모지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: r.hasPhoto
                          ? Image.file(File(r.imagePath!), width: 52, height: 52, fit: BoxFit.cover,
                              errorBuilder: (_,__,___) => _emojiBadge(r))
                          : _emojiBadge(r),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(r.spotName ?? r.fishName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kNavy)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _tag(r.fishName, kPrimary.withOpacity(0.1), kPrimary),
                        _tag('${r.count}마리', const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
                        if (r.hasPhoto) _tag('📷', Colors.orange.shade50, Colors.orange.shade700),
                        if (hasLocation) _tag('지도등록', kOrange.withOpacity(0.1), kOrange),
                        if (r.lengthCm != null) _tag('${r.lengthCm!.toStringAsFixed(1)}cm', kBlue.withOpacity(0.1), kBlue),
                        if (r.memo.isNotEmpty) _tag('메모', Colors.purple.shade50, Colors.purple.shade400),
                      ]),
                      if (hasLocation && r.locationName != null && r.locationName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.location_on, size: 12, color: kSub), const SizedBox(width: 4),
                            Expanded(child: Text(r.locationName!, style: const TextStyle(fontSize: 11, color: kSub, height: 1.2),
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(r.dateStr, style: const TextStyle(color: kSub, fontSize: 12)),
                      const SizedBox(height: 6),
                      // ⭐ 상세보기 화살표
                      const Icon(Icons.chevron_right, size: 18, color: kSub),
                    ]),
                  ]),
                ),
                const Divider(height: 1, color: kBorder),
                // 하단 버튼 행
                SizedBox(
                  height: 40,
                  child: Row(children: [
                    // 삭제
                    Expanded(child: TextButton.icon(
                      onPressed: () { setState(() => _dragX = 0); widget.onDelete(); },
                      icon: const Icon(Icons.delete_outline, size: 16, color: kRed),
                      label: const Text('삭제', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.bold)),
                    )),
                    Container(width: 1, height: 20, color: kBorder),
                    // 글 만들기 ⭐
                    Expanded(child: TextButton.icon(
                      onPressed: widget.onOpenDetail,
                      icon: const Icon(Icons.article_outlined, size: 16, color: kBlue),
                      label: const Text('상세/글 만들기', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emojiBadge(UnifiedCatchRecord r) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: Text(r.emoji, style: const TextStyle(fontSize: 28)),
  );

  Widget _tag(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}