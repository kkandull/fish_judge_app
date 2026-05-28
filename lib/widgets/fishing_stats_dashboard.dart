// lib/widgets/fishing_stats_dashboard.dart
// 도감 상단 — 수집 현황 제거, 나만의 낚시 통계 대시보드

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/unified_catch_record.dart';
import '../services/catch_record_repository.dart';

const Color _kBlue   = Color(0xFF1976D2);
const Color _kNavy   = Color(0xFF1A1A2E);
const Color _kSub    = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);

class FishingStatsDashboard extends StatefulWidget {
  const FishingStatsDashboard({super.key});

  @override
  State<FishingStatsDashboard> createState() => _FishingStatsDashboardState();
}

class _FishingStatsDashboardState extends State<FishingStatsDashboard> {
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await CatchRecordRepository.instance.getAll();
    if (!mounted) return;
    setState(() => _stats = _Stats.from(all));
  }

  @override
  Widget build(BuildContext context) {
    if (_stats == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final s = _stats!;

    // 기록 없음
    if (s.totalCount == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.bar_chart, color: _kBlue, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('나만의 낚시 통계', style: TextStyle(fontSize:14,fontWeight:FontWeight.w900,color:_kNavy)),
                  SizedBox(height: 4),
                  Text('조과를 기록하면 통계가 쌓여요', style: TextStyle(fontSize:12,color:_kSub)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius:8, offset:const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: _kBlue, size: 18),
                const SizedBox(width: 6),
                const Text('나만의 낚시 통계',
                    style: TextStyle(fontSize:14, fontWeight:FontWeight.w900, color:_kNavy)),
                const Spacer(),
                Text('${DateTime.now().year}년',
                    style: const TextStyle(fontSize:11, color:_kSub, fontWeight:FontWeight.w600)),
              ],
            ),
          ),

          // 상단 요약 3칸
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _summaryTile('총 조과', '${s.totalCount}마리', Icons.set_meal, _kBlue),
                const SizedBox(width: 8),
                _summaryTile('낚은 어종', '${s.uniqueSpecies}종', Icons.category, const Color(0xFF03C75A)),
                const SizedBox(width: 8),
                _summaryTile('올해', '${s.thisYearCount}마리', Icons.calendar_today, const Color(0xFFF97316)),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 12),

          // 최대어
          if (s.biggestRecord != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _biggestFishCard(s.biggestRecord!),
            ),

          const SizedBox(height: 10),

          // 올해 많이 잡은 어종 TOP3
          if (s.topSpecies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _topSpeciesSection(s.topSpecies),
            ),

          // 최근 출조
          if (s.lastCatchDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: _kSub),
                  const SizedBox(width: 4),
                  Text('마지막 출조 ${_daysAgo(s.lastCatchDate!)}',
                      style: const TextStyle(fontSize: 11, color: _kSub)),
                  const Spacer(),
                  // 개인 기록 PB 배지
                  if (s.biggestRecord?.lengthCm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6F00).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🏆 PB ${s.biggestRecord!.lengthCm!.toStringAsFixed(1)}cm',
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6F00),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: _kSub, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _biggestFishCard(UnifiedCatchRecord r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFF6F00).withOpacity(0.08), const Color(0xFFFFA000).withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6F00).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: r.hasPhoto
                ? ClipOval(child: Image.file(File(r.imagePath!), width:44, height:44, fit:BoxFit.cover))
                : Text(r.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.emoji_events, size: 13, color: Color(0xFFFF6F00)),
                  const SizedBox(width: 4),
                  const Text('나의 최대어', style: TextStyle(fontSize: 11, color: Color(0xFFFF6F00), fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 3),
                Text(r.fishName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kNavy)),
                Row(children: [
                  if (r.lengthCm != null) Text('${r.lengthCm!.toStringAsFixed(1)}cm',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F00), fontWeight: FontWeight.bold)),
                  if (r.lengthCm != null && r.weightG != null) const Text('  ·  ', style: TextStyle(color: _kSub)),
                  if (r.weightG != null) Text(r.weightG! >= 1000
                      ? '${(r.weightG!/1000).toStringAsFixed(2)}kg'
                      : '${r.weightG!.toStringAsFixed(0)}g',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F00), fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_dateStr(r.catchTime), style: const TextStyle(fontSize: 10, color: _kSub)),
              if (r.displayLocation != '위치 정보 없음')
                Text(r.displayLocation.length > 10
                    ? '${r.displayLocation.substring(0,10)}...'
                    : r.displayLocation,
                    style: const TextStyle(fontSize: 10, color: _kSub)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topSpeciesSection(List<_SpeciesStat> top) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.leaderboard, size: 14, color: _kBlue),
          SizedBox(width: 5),
          Text('올해 많이 잡은 어종', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kNavy)),
        ]),
        const SizedBox(height: 8),
        ...top.asMap().entries.map((e) {
          final rank = e.key + 1;
          final stat = e.value;
          final rankColor = rank == 1 ? const Color(0xFFFFD700)
              : rank == 2 ? const Color(0xFFB0BEC5)
              : const Color(0xFFCD7F32);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$rank', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(stat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy))),
              Text('${stat.count}마리', style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.bold)),
            ]),
          );
        }),
      ],
    );
  }

  String _daysAgo(DateTime dt) {
    final d = DateTime.now().difference(dt).inDays;
    if (d == 0) return '오늘';
    if (d == 1) return '어제';
    if (d < 7) return '$d일 전';
    return '${(d/7).floor()}주 전';
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')}';
}

// ── 통계 계산 ─────────────────────────────────────

class _Stats {
  final int totalCount;
  final int uniqueSpecies;
  final int thisYearCount;
  final UnifiedCatchRecord? biggestRecord;  // 길이 기준
  final List<_SpeciesStat> topSpecies;      // 올해 TOP3
  final DateTime? lastCatchDate;

  _Stats({
    required this.totalCount,
    required this.uniqueSpecies,
    required this.thisYearCount,
    this.biggestRecord,
    required this.topSpecies,
    this.lastCatchDate,
  });

  static _Stats from(List<UnifiedCatchRecord> all) {
    if (all.isEmpty) {
      return _Stats(totalCount:0, uniqueSpecies:0, thisYearCount:0, topSpecies:[], lastCatchDate:null);
    }

    final year = DateTime.now().year;
    final thisYear = all.where((r) => r.catchTime.year == year).toList();

    // 총 마릿수 (count 합산)
    final totalCount = all.fold(0, (sum, r) => sum + r.count);
    final thisYearCount = thisYear.fold(0, (sum, r) => sum + r.count);

    // 고유 어종
    final species = all.map((r) => r.fishName).toSet();

    // 최대어 (길이 기준, 없으면 무게 기준)
    UnifiedCatchRecord? biggest;
    for (final r in all) {
      if (r.lengthCm == null && r.weightG == null) continue;
      if (biggest == null) { biggest = r; continue; }
      final aLen = r.lengthCm ?? 0;
      final bLen = biggest.lengthCm ?? 0;
      if (aLen > bLen) biggest = r;
      else if (aLen == bLen && (r.weightG ?? 0) > (biggest.weightG ?? 0)) biggest = r;
    }

    // 올해 어종별 마릿수 TOP3
    final speciesCount = <String, int>{};
    for (final r in thisYear) {
      speciesCount[r.fishName] = (speciesCount[r.fishName] ?? 0) + r.count;
    }
    final sorted = speciesCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).map((e) => _SpeciesStat(name: e.key, count: e.value)).toList();

    // 마지막 조과일
    final dates = all.map((r) => r.catchTime).toList()..sort();
    final lastDate = dates.isNotEmpty ? dates.last : null;

    return _Stats(
      totalCount: totalCount,
      uniqueSpecies: species.length,
      thisYearCount: thisYearCount,
      biggestRecord: biggest,
      topSpecies: top,
      lastCatchDate: lastDate,
    );
  }
}

class _SpeciesStat {
  final String name;
  final int count;
  _SpeciesStat({required this.name, required this.count});
}