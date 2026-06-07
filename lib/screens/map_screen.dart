// lib/screens/map_screen.dart
// ✅ 전국 낚시 포인트 확장 + 지도 최적화

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
import 'catch_record_detail_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 디자인 토큰
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const Color kPrimary = Color(0xFF1565C0);
const Color kNavy    = Color(0xFF0D1B2A);
const Color kBg      = Color(0xFFF0F4F8);
const Color kCard    = Colors.white;
const Color kRed     = Color(0xFFE53935);
const Color kSub     = Color(0xFF607080);
const Color kBorder  = Color(0xFFDDE3EA);
const Color kOrange  = Color(0xFFFF6D00);
const Color kTeal    = Color(0xFF00ACC1);
const Color kGreen   = Color(0xFF2E7D32);

enum MarkerKind { official, userSpot }
enum Region { all, busan, gyeongnam, jeonnam, jeju, gyeongbuk, gangwon, incheon, chungnam }

extension RegionLabel on Region {
  String get label => switch(this) {
    Region.all => '전체',
    Region.busan => '부산',
    Region.gyeongnam => '경남',
    Region.jeonnam => '전남',
    Region.jeju => '제주',
    Region.gyeongbuk => '경북',
    Region.gangwon => '강원',
    Region.incheon => '인천',
    Region.chungnam => '충남',
  };
}

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
  final Region region;
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
    required this.region,
    this.record,
  });

  bool get isUser => kind == MarkerKind.userSpot;
  LatLng get latLng => LatLng(lat, lng);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ⭐ 전국 낚시 포인트 데이터
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const List<MapMarker> kNationalSpots = [

  // ── 부산 ───────────────────────────────────────────
  MapMarker(id:'bs_haeundae',   name:'해운대 방파제',    region:Region.busan,    species:['전갱이','고등어','볼락'],     diff:'초보', lat:35.1588, lng:129.1603, tip:'새벽 입질이 강해요.',             icon:'🌊', kind:MarkerKind.official),
  MapMarker(id:'bs_gwangan',    name:'광안리 방파제',    region:Region.busan,    species:['감성돔','우럭','노래미'],     diff:'중급', lat:35.1531, lng:129.1186, tip:'물때 3~5물 조과 최고.',            icon:'🌉', kind:MarkerKind.official),
  MapMarker(id:'bs_gijang',     name:'기장 동백 방파제', region:Region.busan,    species:['도다리','볼락','전갱이'],     diff:'초보', lat:35.2446, lng:129.2177, tip:'봄 도다리 명소.',                  icon:'🌸', kind:MarkerKind.official),
  MapMarker(id:'bs_gamcheon',   name:'감천항 동방파제',  region:Region.busan,    species:['감성돔','볼락','전갱이'],     diff:'중급', lat:35.0785, lng:128.9977, tip:'수심 깊어 대물 출현.',             icon:'⚓', kind:MarkerKind.official),
  MapMarker(id:'bs_dadaepo',    name:'다대포 방파제',    region:Region.busan,    species:['광어','우럭','쥐노래미'],     diff:'초보', lat:35.0472, lng:128.9611, tip:'가족 낚시 추천.',                  icon:'🏖️', kind:MarkerKind.official),
  MapMarker(id:'bs_amnam',      name:'암남공원 갯바위',  region:Region.busan,    species:['벵에돔','감성돔','독가시치'], diff:'고급', lat:35.0601, lng:129.0061, tip:'독가시치 주의! 장갑 필수.',        icon:'⚠️', kind:MarkerKind.official),
  MapMarker(id:'bs_taejongdae', name:'영도 태종대',      region:Region.busan,    species:['참돔','벵에돔','쥐노래미'],   diff:'중급', lat:35.0530, lng:129.0850, tip:'조류 강해 채비 무겁게.',            icon:'🗿', kind:MarkerKind.official),
  MapMarker(id:'bs_songjeong',  name:'송정 방파제',      region:Region.busan,    species:['전갱이','고등어','삼치'],     diff:'초보', lat:35.1794, lng:129.2037, tip:'가을 삼치 루어 명소.',             icon:'🎣', kind:MarkerKind.official),
  MapMarker(id:'bs_ilgwang',    name:'일광 방파제',      region:Region.busan,    species:['볼락','도다리','광어'],       diff:'초보', lat:35.2712, lng:129.2298, tip:'봄·가을 볼락 포인트.',            icon:'🐟', kind:MarkerKind.official),

  // ── 경남 ───────────────────────────────────────────
  MapMarker(id:'gn_tongyeong',  name:'통영 한산도',      region:Region.gyeongnam,species:['참돔','감성돔','볼락'],       diff:'중급', lat:34.8370, lng:128.4210, tip:'봄·가을 참돔 최고 포인트.',        icon:'🏝️', kind:MarkerKind.official),
  MapMarker(id:'gn_geoje',      name:'거제 학동 몽돌해변',region:Region.gyeongnam,species:['감성돔','볼락','고등어'],     diff:'중급', lat:34.7720, lng:128.7010, tip:'몽돌 갯바위 명소.',               icon:'🪨', kind:MarkerKind.official),
  MapMarker(id:'gn_namhae',     name:'남해 미조항',      region:Region.gyeongnam,species:['갈치','삼치','방어'],         diff:'초보', lat:34.7340, lng:128.0570, tip:'가을 갈치 낚시 명소.',             icon:'🎏', kind:MarkerKind.official),
  MapMarker(id:'gn_goseong',    name:'고성 자란만',      region:Region.gyeongnam,species:['감성돔','볼락','도다리'],     diff:'중급', lat:34.9440, lng:128.2610, tip:'내만 조용한 포인트.',              icon:'🌿', kind:MarkerKind.official),
  MapMarker(id:'gn_sacheon',    name:'사천 삼천포항',    region:Region.gyeongnam,species:['볼락','우럭','전갱이'],       diff:'초보', lat:35.0040, lng:128.0620, tip:'방파제 야간 볼락 명소.',           icon:'🌙', kind:MarkerKind.official),
  MapMarker(id:'gn_hadong',     name:'하동 금남 방파제', region:Region.gyeongnam,species:['숭어','감성돔','전어'],       diff:'초보', lat:34.9870, lng:127.9070, tip:'봄 전어·숭어 포인트.',             icon:'🌱', kind:MarkerKind.official),

  // ── 전남 ───────────────────────────────────────────
  MapMarker(id:'jn_yeosu',      name:'여수 돌산도',      region:Region.jeonnam,  species:['감성돔','참돔','볼락'],       diff:'중급', lat:34.6640, lng:127.8040, tip:'갯바위 감성돔 명소.',              icon:'🌊', kind:MarkerKind.official),
  MapMarker(id:'jn_wando',      name:'완도 청산도',      region:Region.jeonnam,  species:['참돔','벵에돔','감성돔'],     diff:'고급', lat:34.1860, lng:126.8690, tip:'원도 낚시 최고급 포인트.',         icon:'🏔️', kind:MarkerKind.official),
  MapMarker(id:'jn_mokpo',      name:'목포 달리도',      region:Region.jeonnam,  species:['농어','감성돔','전어'],       diff:'중급', lat:34.7680, lng:126.3340, tip:'조류 강한 농어 포인트.',           icon:'🌀', kind:MarkerKind.official),
  MapMarker(id:'jn_goheung',    name:'고흥 나로도',      region:Region.jeonnam,  species:['참돔','벵에돔','쥐치'],       diff:'중급', lat:34.5070, lng:127.5530, tip:'청정 해역 다양한 어종.',           icon:'🦀', kind:MarkerKind.official),
  MapMarker(id:'jn_jindo',      name:'진도 울돌목',      region:Region.jeonnam,  species:['참돔','방어','농어'],         diff:'고급', lat:34.5500, lng:126.3040, tip:'빠른 조류, 대형어 출현.',          icon:'⚡', kind:MarkerKind.official),
  MapMarker(id:'jn_sinan',      name:'신안 비금도',      region:Region.jeonnam,  species:['감성돔','벵에돔','참돔'],     diff:'고급', lat:34.7520, lng:125.9890, tip:'서해 원도 낚시 명소.',             icon:'💎', kind:MarkerKind.official),
  MapMarker(id:'jn_boryeong',   name:'보성 벌교 방파제', region:Region.jeonnam,  species:['숭어','감성돔','전어'],       diff:'초보', lat:34.8440, lng:127.3480, tip:'잔잔한 내만 초보 추천.',           icon:'🌾', kind:MarkerKind.official),

  // ── 제주 ───────────────────────────────────────────
  MapMarker(id:'jj_seogwipo',   name:'서귀포 외돌개',    region:Region.jeju,     species:['벵에돔','감성돔','자리돔'],   diff:'고급', lat:33.2380, lng:126.5530, tip:'제주 최고의 벵에돔 포인트.',       icon:'🌺', kind:MarkerKind.official),
  MapMarker(id:'jj_mosulpo',    name:'모슬포 방파제',    region:Region.jeju,     species:['방어','부시리','참돔'],       diff:'중급', lat:33.2130, lng:126.2490, tip:'겨울 방어 낚시 명소.',             icon:'🐠', kind:MarkerKind.official),
  MapMarker(id:'jj_hamdeok',    name:'함덕 방파제',      region:Region.jeju,     species:['자리돔','볼락','전갱이'],     diff:'초보', lat:33.5430, lng:126.6640, tip:'초보·가족 낚시 추천.',             icon:'🏄', kind:MarkerKind.official),
  MapMarker(id:'jj_ilchulbong', name:'성산 일출봉 갯바위',region:Region.jeju,    species:['벵에돔','감성돔','독가시치'], diff:'고급', lat:33.4580, lng:126.9420, tip:'수중 지형 복잡, 대물 포인트.',     icon:'🌅', kind:MarkerKind.official),
  MapMarker(id:'jj_aewol',      name:'애월 방파제',      region:Region.jeju,     species:['자리돔','전갱이','볼락'],     diff:'초보', lat:33.4640, lng:126.3200, tip:'석양 낚시 명소.',                  icon:'🌇', kind:MarkerKind.official),
  MapMarker(id:'jj_udo',        name:'우도 방파제',      region:Region.jeju,     species:['방어','부시리','벵에돔'],     diff:'중급', lat:33.5060, lng:126.9520, tip:'블루오션 원도 낚시.',              icon:'🐬', kind:MarkerKind.official),

  // ── 경북 ───────────────────────────────────────────
  MapMarker(id:'gb_pohang',     name:'포항 구룡포항',    region:Region.gyeongbuk,species:['도루묵','대구','방어'],       diff:'초보', lat:35.9870, lng:129.5580, tip:'겨울 대구·도루묵 명소.',           icon:'❄️', kind:MarkerKind.official),
  MapMarker(id:'gb_ulleung',    name:'울릉도 저동항',    region:Region.gyeongbuk,species:['오징어','방어','부시리'],     diff:'중급', lat:37.4910, lng:130.9080, tip:'여름 오징어 루어 최고.',            icon:'🦑', kind:MarkerKind.official),
  MapMarker(id:'gb_yeongdeok',  name:'영덕 강구항',      region:Region.gyeongbuk,species:['대게','볼락','노래미'],       diff:'초보', lat:36.5340, lng:129.4100, tip:'봄 대게 포인트.',                  icon:'🦀', kind:MarkerKind.official),
  MapMarker(id:'gb_gyeongju',   name:'경주 감포항',      region:Region.gyeongbuk,species:['감성돔','볼락','전갱이'],     diff:'초보', lat:35.8000, lng:129.5010, tip:'방파제 초보 추천.',                icon:'⛩️', kind:MarkerKind.official),
  MapMarker(id:'gb_uljin',      name:'울진 죽변항',      region:Region.gyeongbuk,species:['대구','방어','볼락'],         diff:'초보', lat:37.0580, lng:129.4210, tip:'겨울 대구 낚시 명소.',             icon:'🏔️', kind:MarkerKind.official),

  // ── 강원 ───────────────────────────────────────────
  MapMarker(id:'gw_sokcho',     name:'속초 외옹치항',    region:Region.gangwon,  species:['방어','부시리','가자미'],     diff:'중급', lat:38.2170, lng:128.6140, tip:'가을 방어 루어 명소.',             icon:'🍂', kind:MarkerKind.official),
  MapMarker(id:'gw_gangneung',  name:'강릉 안목항',      region:Region.gangwon,  species:['도루묵','방어','전갱이'],     diff:'초보', lat:37.7750, lng:128.9500, tip:'커피거리 근처 방파제.',            icon:'☕', kind:MarkerKind.official),
  MapMarker(id:'gw_donghae',    name:'동해 묵호항',      region:Region.gangwon,  species:['가자미','볼락','노래미'],     diff:'초보', lat:37.5500, lng:129.1200, tip:'사계절 가자미 포인트.',            icon:'🌊', kind:MarkerKind.official),
  MapMarker(id:'gw_samcheok',   name:'삼척 임원항',      region:Region.gangwon,  species:['방어','오징어','가자미'],     diff:'중급', lat:37.2200, lng:129.3500, tip:'가을 방어 떼 출몰.',               icon:'🎯', kind:MarkerKind.official),
  MapMarker(id:'gw_goseong',    name:'고성 거진항',      region:Region.gangwon,  species:['명태','도루묵','가자미'],     diff:'초보', lat:38.4370, lng:128.4790, tip:'동해 최북단 낚시 포인트.',         icon:'🌨️', kind:MarkerKind.official),

  // ── 인천/서해 ──────────────────────────────────────
  MapMarker(id:'ic_palmido',    name:'인천 팔미도',      region:Region.incheon,  species:['농어','우럭','광어'],         diff:'중급', lat:37.3060, lng:126.4880, tip:'서해 농어 루어 명소.',             icon:'🏮', kind:MarkerKind.official),
  MapMarker(id:'ic_deokjeok',   name:'인천 덕적도',      region:Region.incheon,  species:['우럭','광어','농어'],         diff:'중급', lat:37.2210, lng:125.9620, tip:'섬낚시 대물 포인트.',             icon:'🏝️', kind:MarkerKind.official),
  MapMarker(id:'ic_muui',       name:'영종도 무의도',    region:Region.incheon,  species:['우럭','광어','숭어'],         diff:'초보', lat:37.4200, lng:126.4090, tip:'당일치기 섬낚시.',                icon:'⛵', kind:MarkerKind.official),
  MapMarker(id:'ic_jawoldo',    name:'자월도 방파제',    region:Region.incheon,  species:['우럭','놀래기','볼락'],       diff:'초보', lat:37.2610, lng:126.0890, tip:'조용한 방파제 낚시.',             icon:'🌙', kind:MarkerKind.official),

  // ── 충남/서해 ──────────────────────────────────────
  MapMarker(id:'cn_boryeong',   name:'보령 무창포',      region:Region.chungnam, species:['우럭','광어','농어'],         diff:'초보', lat:36.3450, lng:126.5000, tip:'모세의 기적 갯벌 낚시.',           icon:'🌊', kind:MarkerKind.official),
  MapMarker(id:'cn_taean',      name:'태안 학암포',      region:Region.chungnam, species:['광어','우럭','농어'],         diff:'초보', lat:36.9040, lng:126.1940, tip:'서해 광어 최고 포인트.',           icon:'🏖️', kind:MarkerKind.official),
  MapMarker(id:'cn_seocheon',   name:'서천 마량항',      region:Region.chungnam, species:['꽃게','숭어','농어'],         diff:'초보', lat:36.2080, lng:126.6290, tip:'꽃게 낚시 명소.',                  icon:'🦀', kind:MarkerKind.official),
  MapMarker(id:'cn_anmyeon',    name:'안면도 방파제',    region:Region.chungnam, species:['광어','우럭','농어'],         diff:'초보', lat:36.4800, lng:126.3200, tip:'서해 가족 낚시 명소.',             icon:'🌅', kind:MarkerKind.official),
];

const LatLng kKoreaCenter = LatLng(36.0, 127.9);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Root
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
    final officialNames = kNationalSpots.map((s) => s.name).toSet();

    for (final r in all) {
      if (r.latitude == null || r.longitude == null) continue;
      final name = r.spotName ?? r.fishName;
      if (officialNames.contains(name)) continue;
      if (!seenIds.add(r.id)) continue;
      spots.add(MapMarker(
        id: r.id, name: name, species: [r.fishName], diff: '사용자',
        lat: r.latitude!, lng: r.longitude!,
        tip: r.memo.isEmpty ? '내가 직접 추가한 포인트' : r.memo,
        icon: r.emoji, kind: MarkerKind.userSpot,
        region: Region.all, record: r,
      ));
    }
    setState(() {
      _records = all;
      _userSpots = spots;
      if (_selectedMarker != null) {
        final stillExists = [...kNationalSpots, ..._userSpots].any((m) => m.id == _selectedMarker!.id);
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
          Text('"${r.spotName ?? r.fishName}" 기록을 삭제할까요?\n도감과 지도에서 함께 사라집니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kSub, height: 1.5)),
        ]),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: kSub)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () { Navigator.pop(ctx); _deleteRecord(r.id); },
              child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ],
      ),
    );
  }

  void _openDetail(UnifiedCatchRecord r) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CatchRecordDetailScreen(record: r)));
  }

  Future<void> _showAddSheet() async {
    await showUnifiedCatchForm(context, createdFrom: 'map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kNavy,
        title: const Text('낚시 포인트 지도',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.3)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_outlined, size: 15), SizedBox(width: 5), Text('포인트 지도'),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.menu_book_outlined, size: 15),
              const SizedBox(width: 5),
              const Text('조과 일지'),
              if (_records.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_records.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MapTab(
            officialSpots: kNationalSpots,
            userSpots: _userSpots,
            selectedMarker: _selectedMarker,
            onSelectMarker: (m) => setState(() => _selectedMarker = (_selectedMarker?.id == m?.id) ? null : m),
            onDeleteUserSpot: (m) { if (m.record != null) _confirmDeleteRecord(m.record!); },
            onOpenDetail: (m) { if (m.record != null) _openDetail(m.record!); },
            onAddRecord: _showAddSheet,
          ),
          _JournalTab(
            records: _records,
            onDelete: _confirmDeleteRecord,
            onOpenDetail: _openDetail,
            onAddRecord: _showAddSheet,
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 지도 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MapTab extends StatefulWidget {
  final List<MapMarker> officialSpots;
  final List<MapMarker> userSpots;
  final MapMarker? selectedMarker;
  final Function(MapMarker?) onSelectMarker;
  final Function(MapMarker) onDeleteUserSpot;
  final Function(MapMarker) onOpenDetail;
  final VoidCallback onAddRecord;

  const _MapTab({
    required this.officialSpots, required this.userSpots,
    required this.selectedMarker, required this.onSelectMarker,
    required this.onDeleteUserSpot, required this.onOpenDetail,
    required this.onAddRecord,
  });

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final MapController _mapCtrl = MapController();
  StreamSubscription<MapEvent>? _mapEventSub;

  // ⭐ 지역 필터 + 난이도 필터
  Region _regionFilter = Region.all;
  String _diffFilter = '전체';
  final _diffs = ['전체', '추천장소', '사용자'];

  bool _offline = false;
  int _tileErrorCount = 0; // 타일 에러 누적 카운트
  double _currentRotation = 0;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _mapEventSub = _mapCtrl.mapEventStream.listen((e) {
      if (!mounted) return;
      try {
        final rot = _mapCtrl.camera.rotation;
        if ((rot - _currentRotation).abs() > 0.5) setState(() => _currentRotation = rot);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  List<MapMarker> get _allSpots => [...widget.officialSpots, ...widget.userSpots];

  List<MapMarker> get _filtered {
    var list = _allSpots;
    if (_regionFilter != Region.all) {
      list = list.where((s) => s.region == _regionFilter || s.isUser).toList();
    }
    if (_diffFilter == '추천장소') {
      list = list.where((s) => !s.isUser).toList();
    } else if (_diffFilter == '사용자') {
      list = list.where((s) => s.isUser).toList();
    }
    return list;
  }

  Color _diffColor(String d) => switch(d) {
    '추천장소' => kPrimary, '사용자' => kTeal, _ => kPrimary,
  };

  void _moveTo(LatLng pos, {double? zoom}) {
    try { _mapCtrl.move(pos, zoom ?? _mapCtrl.camera.zoom); } catch (_) {}
  }
  void _zoomIn()  { try { final z = _mapCtrl.camera.zoom; if (z < 18) _mapCtrl.move(_mapCtrl.camera.center, z+1); } catch(_) {} }
  void _zoomOut() { try { final z = _mapCtrl.camera.zoom; if (z > 5)  _mapCtrl.move(_mapCtrl.camera.center, z-1); } catch(_) {} }

  // ⭐ 지역 선택 시 해당 지역으로 이동
  static const Map<Region, LatLng> _regionCenter = {
    Region.all:       LatLng(36.0, 127.9),
    Region.busan:     LatLng(35.15, 129.05),
    Region.gyeongnam: LatLng(34.95, 128.25),
    Region.jeonnam:   LatLng(34.65, 127.0),
    Region.jeju:      LatLng(33.38, 126.55),
    Region.gyeongbuk: LatLng(36.5,  129.25),
    Region.gangwon:   LatLng(37.8,  128.9),
    Region.incheon:   LatLng(37.35, 126.45),
    Region.chungnam:  LatLng(36.55, 126.6),
  };
  static const Map<Region, double> _regionZoom = {
    Region.all: 7.0, Region.busan: 11.5, Region.gyeongnam: 10.5,
    Region.jeonnam: 9.5, Region.jeju: 10.0, Region.gyeongbuk: 10.0,
    Region.gangwon: 10.0, Region.incheon: 10.5, Region.chungnam: 10.5,
  };

  Future<void> _goToCurrentLocation() async {
    if (_gpsLoading) return;
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) { _showSnack('위치 권한이 필요합니다.', isError: true); _moveTo(kKoreaCenter, zoom: 7); }
        return;
      }
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) { if (mounted) { _showSnack('GPS가 꺼져있습니다.', isError: true); } return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 8));
      if (!mounted) return;
      _moveTo(LatLng(pos.latitude, pos.longitude), zoom: 12);
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) _showSnack('위치를 가져올 수 없어요.', isError: true);
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

  // ⭐ 마커 — 난이도별 색상, 선택 시 크기 확대
  Marker _buildMarker(MapMarker m) {
    final isSel = widget.selectedMarker?.id == m.id;
    final sz = isSel ? 52.0 : 44.0;
    final col = m.isUser ? kTeal : kPrimary;
    return Marker(
      point: m.latLng, width: sz, height: sz,
      child: GestureDetector(
        onTap: () { widget.onSelectMarker(m); _moveTo(m.latLng); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: sz, height: sz,
          decoration: BoxDecoration(
            color: isSel ? kNavy : col,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSel ? 3 : 2),
            boxShadow: [
              BoxShadow(color: col.withOpacity(isSel ? 0.6 : 0.3),
                blurRadius: isSel ? 12 : 6, spreadRadius: isSel ? 2 : 0),
            ],
          ),
          alignment: Alignment.center,
          child: m.isUser
              ? Text(m.icon, style: TextStyle(fontSize: isSel ? 22 : 18))
              : Icon(Icons.place, color: Colors.white, size: isSel ? 24 : 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _filtered.map(_buildMarker).toList();
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth, height: constraints.maxHeight,
        child: Stack(children: [

          // 지도
          Positioned.fill(child: ColoredBox(
            color: const Color(0xFFF2F4F5), // OSM 기본 배경
            child: ClipRect(child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: kKoreaCenter,
              initialZoom: 7.0,
              minZoom: 6.0,
              maxZoom: 18,
              // ✅ 드래그 가능 범위를 한국 주변으로 제한
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(
                  const LatLng(31.0, 123.5), // 남서쪽 끝 (제주 아래)
                  const LatLng(39.0, 132.5), // 북동쪽 끝 (독도 위)
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) { if (widget.selectedMarker != null) widget.onSelectMarker(null); },
            ),
            children: [
              TileLayer(
                // ✅ OpenStreetMap — 전 세계 무료, 회색 영역 없음
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.busan_fush_app',
                errorTileCallback: (tile, error, _) {
                  _tileErrorCount++;
                  if (mounted && !_offline && _tileErrorCount >= 3)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _offline = true);
                    });
                },
              ),
              MarkerLayer(markers: markers),
            ],
          )))),

          // 오프라인 경고
          if (_offline)
            Positioned(top: 12, left: 16, right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 15), SizedBox(width: 8),
                  Flexible(child: Text('인터넷 연결을 확인해주세요',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                ]),
              ),
            ),

          // 정보 팝업
          if (widget.selectedMarker != null)
            Positioned(top: 12, left: 16, right: 68,
              child: _InfoPopup(
                marker: widget.selectedMarker!,
                onClose: () => widget.onSelectMarker(null),
                onDelete: () => widget.onDeleteUserSpot(widget.selectedMarker!),
                onOpenDetail: () => widget.onOpenDetail(widget.selectedMarker!),
              ),
            ),

          // 우측 컨트롤
          Positioned(top: 12, right: 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ctrlBtn(Icons.add, _zoomIn),
              const SizedBox(height: 6),
              _ctrlBtn(Icons.remove, _zoomOut),
              const SizedBox(height: 6),
              _ctrlBtn(_gpsLoading ? Icons.hourglass_top : Icons.my_location_rounded,
                _goToCurrentLocation, color: kPrimary, loading: _gpsLoading),
            ]),
          ),

          // ⭐ 하단 시트 — 지역 + 난이도 필터 + 포인트 목록
          DraggableScrollableSheet(
            initialChildSize: 0.32, minChildSize: 0.12, maxChildSize: 0.85,
            builder: (ctx, sc) => Container(
              decoration: const BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0,-5))],
              ),
              child: CustomScrollView(controller: sc, slivers: [
                SliverToBoxAdapter(child: Center(
                  child: Container(width: 40, height: 5, margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
                )),

                // ⭐ 지역 필터 (가로 스크롤)
                SliverToBoxAdapter(child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: Region.values.map((r) {
                      final isActive = _regionFilter == r;
                      return GestureDetector(
                        onTap: () {
                          setState(() { _regionFilter = r; });
                          widget.onSelectMarker(null);
                          _moveTo(_regionCenter[r]!, zoom: _regionZoom[r]);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? kNavy : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(r.label,
                            style: TextStyle(
                              color: isActive ? Colors.white : kSub,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // 난이도 필터 + 개수
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    Expanded(child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _diffs.map((d) {
                        final isActive = _diffFilter == d;
                        return GestureDetector(
                          onTap: () { setState(() => _diffFilter = d); widget.onSelectMarker(null); },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? _diffColor(d).withOpacity(0.15) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive ? _diffColor(d) : Colors.grey[200]!, width: 1.5),
                            ),
                            child: Text(d, style: TextStyle(
                              color: isActive ? _diffColor(d) : kSub,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        );
                      }).toList()),
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('${_filtered.length}곳',
                        style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                )),

                // 포인트 목록
                if (_filtered.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎣', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('해당 조건의 포인트가 없어요',
                        style: const TextStyle(color: kSub, fontSize: 13)),
                    ]),
                  ))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final spot = _filtered[i];
                        final isSel = widget.selectedMarker?.id == spot.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SpotListCard(
                            spot: spot, isSelected: isSel,
                            diffColor: spot.isUser ? kTeal : kPrimary,
                            onTap: () { widget.onSelectMarker(spot); _moveTo(spot.latLng, zoom: 13); },
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

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {Color? color, bool loading = false}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      elevation: 3, shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(20), onTap: loading ? null : onTap,
        child: SizedBox(width: 40, height: 40, child: Center(
          child: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
              : Icon(icon, size: 20, color: color ?? Colors.grey[700]),
        )),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 정보 팝업
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _InfoPopup extends StatelessWidget {
  final MapMarker marker;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;

  const _InfoPopup({required this.marker, required this.onClose,
      required this.onDelete, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final r = marker.record;
    final hasPhoto = r?.imagePath != null;
    return GestureDetector(
      onTap: marker.isUser ? onOpenDetail : null,
      child: SizedBox(
        height: 96,
        child: Material(
          color: Colors.white, elevation: 8,
          borderRadius: BorderRadius.circular(16), shadowColor: Colors.black38,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(children: [
              SizedBox(width: 76, height: 96,
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
                      if (marker.isUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Text('상세', style: TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.bold)))
                      else
                        GestureDetector(onTap: onClose,
                          child: Container(width: 22, height: 22, alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 13, color: kSub))),
                    ]),
                    SizedBox(height: 20,
                      child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.zero,
                        children: marker.species.take(3).map((s) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (marker.isUser ? kTeal : kPrimary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text('#$s', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: marker.isUser ? kTeal : kPrimary)),
                        )).toList(),
                      ),
                    ),
                    Row(children: [
                      Expanded(child: Text(marker.tip, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kSub))),
                      if (marker.isUser) ...[
                        const SizedBox(width: 4),
                        GestureDetector(onTap: onClose,
                          child: Container(width: 22, height: 22, alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 13, color: kSub))),
                        const SizedBox(width: 4),
                        GestureDetector(onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_outline, size: 12, color: kRed), SizedBox(width: 3),
                              Text('삭제', style: TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.bold)),
                            ]))),
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
    width: 76, height: 96,
    color: (m.isUser ? kTeal : kPrimary).withOpacity(0.1),
    alignment: Alignment.center,
    child: Text(m.icon, style: const TextStyle(fontSize: 32)),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 포인트 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _SpotListCard extends StatelessWidget {
  final MapMarker spot;
  final bool isSelected;
  final Color diffColor;
  final VoidCallback onTap;

  const _SpotListCard({required this.spot, required this.isSelected,
      required this.diffColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kNavy : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? diffColor : kBorder,
            width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: diffColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0,4))]
              : [const BoxShadow(color: Color(0x05000000), blurRadius: 6)],
        ),
        child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: isSelected ? diffColor.withOpacity(0.2) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(spot.icon, style: const TextStyle(fontSize: 24))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(spot.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: isSelected ? Colors.white : kNavy))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? diffColor.withOpacity(0.25) : diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(spot.isUser ? '내 포인트' : '추천장소', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : diffColor))),
            ]),
            const SizedBox(height: 5),
            Text(spot.species.map((s) => '#$s').join('  '),
              style: TextStyle(fontSize: 12, color: isSelected ? Colors.white60 : kSub)),
            const SizedBox(height: 2),
            Text(spot.tip, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isSelected ? Colors.white38 : Colors.grey[400])),
          ])),
          Icon(Icons.chevron_right, size: 16, color: isSelected ? Colors.white38 : kBorder),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 조과 일지 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _JournalTab extends StatelessWidget {
  final List<UnifiedCatchRecord> records;
  final Function(UnifiedCatchRecord) onDelete;
  final Function(UnifiedCatchRecord) onOpenDetail;
  final VoidCallback onAddRecord;

  const _JournalTab({required this.records, required this.onDelete,
      required this.onOpenDetail, required this.onAddRecord});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Stack(children: [
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          const Text('🎣', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          const Text('아직 조과 기록이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
          const SizedBox(height: 6),
          const Text('낚시 다녀온 후 기록을 남겨보세요!', style: TextStyle(fontSize: 13, color: kSub)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: onAddRecord,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('첫 기록 남기기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ])),
      ]);
    }

    final totalCount  = records.fold<int>(0, (s, r) => s + r.count);
    final uniqueSpots = records.where((r) => r.spotName != null).map((r) => r.spotName!).toSet().length;
    final uniqueSpec  = records.map((r) => r.fishName).toSet().length;
    final spotAdded   = records.where((r) => r.latitude != null).length;

    return Stack(children: [
      CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNavy, Color(0xFF1565C0)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: kNavy.withOpacity(0.25), blurRadius: 12, offset: const Offset(0,4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('총 출조', '${records.length}회', Icons.directions_boat),
            _vDiv(),
            _stat('포인트', '${uniqueSpots}곳', Icons.place_outlined),
            _vDiv(),
            _stat('어종', '${uniqueSpec}종', Icons.set_meal_outlined),
            _vDiv(),
            _stat('마릿수', '${totalCount}마', Icons.water_drop_outlined),
          ]),
        )),
        if (spotAdded > 0)
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTeal.withOpacity(0.25))),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: kTeal),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '위치 정보가 있는 기록 $spotAdded개가 포인트 지도에 자동 등록됐어요',
                style: const TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w500))),
            ]),
          )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _RecordCard(
              record: records[i],
              onDelete: () => onDelete(records[i]),
              onOpenDetail: () => onOpenDetail(records[i])),
            childCount: records.length,
          )),
        ),
      ]),
      Positioned(
        bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16,
        right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'journal_fab', backgroundColor: kPrimary, elevation: 6,
          onPressed: onAddRecord,
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text('조과 기록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
      ),
    ]);
  }

  Widget _stat(String label, String value, IconData icon) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white54, size: 16), const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  Widget _vDiv() => Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15));
}

class _RecordCard extends StatefulWidget {
  final UnifiedCatchRecord record;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;
  const _RecordCard({required this.record, required this.onDelete, required this.onOpenDetail});
  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  double _dragX = 0;
  static const double _threshold = 72;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final hasLoc = r.latitude != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(children: [
        Positioned.fill(child: Container(
          padding: const EdgeInsets.only(right: 22),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: _dragX < -10 ? kRed : Colors.transparent,
            borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22))),
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() => _dragX = (_dragX + d.delta.dx).clamp(-_threshold, 0.0)),
          onHorizontalDragEnd: (_) => setState(() => _dragX = _dragX < -_threshold/2 ? -_threshold : 0),
          onTap: () {
            if (_dragX < -10) { setState(() => _dragX = 0); }
            else { widget.onOpenDetail(); }
          },
          child: Transform.translate(
            offset: Offset(_dragX, 0),
            child: Container(
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0,3))]),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: r.hasPhoto
                          ? Image.file(File(r.imagePath!), width: 50, height: 50, fit: BoxFit.cover,
                              errorBuilder: (_,__,___) => _emojiBadge(r))
                          : _emojiBadge(r),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(r.spotName ?? r.fishName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kNavy)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 5, runSpacing: 3, children: [
                        _tag(r.fishName, kPrimary.withOpacity(0.1), kPrimary),
                        _tag('${r.count}마리', const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
                        if (r.hasPhoto) _tag('📷', Colors.orange.shade50, Colors.orange.shade700),
                        if (hasLoc) _tag('지도등록', kTeal.withOpacity(0.1), kTeal),
                        if (r.lengthCm != null) _tag('${r.lengthCm!.toStringAsFixed(1)}cm', kPrimary.withOpacity(0.08), kPrimary),
                      ]),
                    ])),
                    const SizedBox(width: 6),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(r.dateStr, style: const TextStyle(color: kSub, fontSize: 11)),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, size: 16, color: kBorder),
                    ]),
                  ]),
                ),
                const Divider(height: 1, color: kBorder),
                SizedBox(height: 38, child: Row(children: [
                  Expanded(child: TextButton.icon(
                    onPressed: () { setState(() => _dragX = 0); widget.onDelete(); },
                    icon: const Icon(Icons.delete_outline, size: 15, color: kRed),
                    label: const Text('삭제', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.bold)))),
                  Container(width: 1, height: 18, color: kBorder),
                  Expanded(child: TextButton.icon(
                    onPressed: widget.onOpenDetail,
                    icon: const Icon(Icons.article_outlined, size: 15, color: kPrimary),
                    label: const Text('상세/글 만들기', style: TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)))),
                ])),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emojiBadge(UnifiedCatchRecord r) => Container(
    width: 50, height: 50,
    decoration: BoxDecoration(color: kPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    alignment: Alignment.center,
    child: Text(r.emoji, style: const TextStyle(fontSize: 26)));

  Widget _tag(String l, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
    child: Text(l, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)));
}