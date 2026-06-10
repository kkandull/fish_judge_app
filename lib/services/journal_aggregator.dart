// JournalSummary에 원본 record 추가 — 상세 화면 연결용

import 'package:flutter/foundation.dart';

import '../models/unified_catch_record.dart';
import 'catch_record_repository.dart';

class JournalSummary {
  final String fishName;
  final DateTime catchTime;
  final String? imagePath;
  final String? locationName;
  final double? lengthCm;
  final double? weightG;
  final String source;
  final int count;
  final String emoji;
  // 상세 화면 연결용 — 원본 record 보관
  final UnifiedCatchRecord record;

  const JournalSummary({
    required this.fishName,
    required this.catchTime,
    this.imagePath,
    this.locationName,
    this.lengthCm,
    this.weightG,
    required this.source,
    this.count = 1,
    this.emoji = '🐟',
    required this.record,
  });

  factory JournalSummary.fromUnified(UnifiedCatchRecord r) => JournalSummary(
        fishName:     r.fishName,
        catchTime:    r.catchTime,
        imagePath:    r.imagePath,
        locationName: r.displayLocation == '위치 정보 없음' ? null : r.displayLocation,
        lengthCm:     r.lengthCm,
        weightG:      r.weightG,
        source:       r.createdFrom,
        count:        r.count,
        emoji:        r.emoji,
        record:       r,
      );
}

class JournalAggregator {
  JournalAggregator._();
  static final JournalAggregator instance = JournalAggregator._();

  Future<List<JournalSummary>> getRecentRecords({int limit = 5}) async {
    try {
      final all = await CatchRecordRepository.instance.getAll();
      return all.take(limit).map(JournalSummary.fromUnified).toList();
    } catch (e) {
      debugPrint('조과 조회 실패: $e');
      return [];
    }
  }

  Future<Map<String, int>> getStats() async {
    try {
      return await CatchRecordRepository.instance.getStats();
    } catch (e) {
      debugPrint('통계 조회 실패: $e');
      return {'totalCount': 0, 'uniqueFishCount': 0};
    }
  }
}