import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/unified_catch_record.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 통합 조과 저장소 (Phase 3)
//
// 모든 조과 기록을 'unified_catch_records' 단일 키에 저장.
// 도감(EncyclopediaScreen)과 지도(MapScreen) 양쪽이 같은 저장소 참조.
//
// 마이그레이션:
//   첫 실행 시 옛 키(records_*, fishing_records_v3)에서 데이터 읽어와
//   통합 저장소로 복사. 한 번만 실행됨 (migration_v3_done 플래그).
//
// 사용:
//   final repo = CatchRecordRepository.instance;
//   await repo.init();  // 앱 시작 시 한 번
//   final records = await repo.getAll();
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CatchRecordRepository {
  CatchRecordRepository._();
  static final CatchRecordRepository instance = CatchRecordRepository._();

  /// 메인 저장소 키
  static const String _kStorageKey = 'unified_catch_records';

  /// 마이그레이션 완료 플래그
  static const String _kMigrationFlag = 'migration_unified_v1_done';

  /// 사용자 추가 어종 목록 (도감과 공유)
  static const String _kCustomFishKey = 'custom_fish_list';

  /// 인메모리 캐시 (변경 시 무효화)
  List<UnifiedCatchRecord>? _cache;

  /// 변경 알림용 스트림 (홈/도감/지도가 구독)
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  /// 변경 알림 스트림. 어디서 데이터 변경되면 모든 구독자에게 통지.
  Stream<void> get changes => _changeController.stream;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 초기화 + 마이그레이션
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 앱 시작 시 1회 호출. 마이그레이션이 필요하면 자동 수행.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final done = prefs.getBool(_kMigrationFlag) ?? false;
    if (done) {
      debugPrint('✓ 마이그레이션 이미 완료됨');
      return;
    }

    debugPrint('🔄 마이그레이션 시작...');
    try {
      await _migrate(prefs);
      await prefs.setBool(_kMigrationFlag, true);
      debugPrint('✅ 마이그레이션 완료');
    } catch (e) {
      debugPrint('❌ 마이그레이션 실패: $e');
      // 실패 시 플래그 안 set → 다음 실행 시 재시도
    }
  }

  /// 옛 데이터를 통합 저장소로 이전
  Future<void> _migrate(SharedPreferences prefs) async {
    final existing = await getAll();
    final existingIds = existing.map((r) => r.id).toSet();
    final migrated = <UnifiedCatchRecord>[];

    // 1) 도감 데이터 (records_<어종이름>)
    final defaultFish = [
      "감성돔", "광어", "우럭", "쥐노래미", "참돔",
      "벵에돔", "독가시치", "볼락", "노래미", "도다리",
    ];
    final customFish = prefs.getStringList(_kCustomFishKey) ?? <String>[];
    final allFish = [...defaultFish, ...customFish];

    for (final fishName in allFish) {
      final jsonStr = prefs.getString('records_$fishName');
      if (jsonStr == null) continue;

      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final catchTimeMs = m['catchTime'] as int?;
          if (catchTimeMs == null) continue;

          final id = 'mig_enc_${catchTimeMs}_${fishName.hashCode}';
          if (existingIds.contains(id)) continue;

          migrated.add(UnifiedCatchRecord(
            id: id,
            fishName: fishName,
            catchTime: DateTime.fromMillisecondsSinceEpoch(catchTimeMs),
            latitude: (m['latitude'] as num?)?.toDouble(),
            longitude: (m['longitude'] as num?)?.toDouble(),
            locationName: m['locationName'] as String?,
            imagePath: m['imagePath'] as String?,
            lengthCm: (m['lengthCm'] as num?)?.toDouble(),
            weightG: (m['weightG'] as num?)?.toDouble(),
            memo: (m['memo'] as String?) ?? '',
            createdFrom: 'encyclopedia',
          ));
          existingIds.add(id);
        }
      } catch (e) {
        debugPrint('도감 마이그레이션 실패 ($fishName): $e');
      }
    }

    // 2) 지도 데이터 (fishing_records_v3)
    final mapRaw = prefs.getStringList('fishing_records_v3') ?? [];
    for (final raw in mapRaw) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final originalId = m['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final id = 'mig_map_$originalId';
        if (existingIds.contains(id)) continue;

        // 'YYYY.MM.DD' 파싱
        final dateStr = m['date']?.toString() ?? '';
        DateTime catchTime;
        try {
          final parts = dateStr.split('.');
          if (parts.length >= 3) {
            catchTime = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
              12, // 시간 정보 없으니 정오로
            );
          } else {
            catchTime = DateTime.now();
          }
        } catch (_) {
          catchTime = DateTime.now();
        }

        migrated.add(UnifiedCatchRecord(
          id: id,
          fishName: m['species']?.toString() ?? '어종 미상',
          catchTime: catchTime,
          latitude: (m['lat'] as num?)?.toDouble(),
          longitude: (m['lng'] as num?)?.toDouble(),
          spotName: m['spotName']?.toString(),
          memo: (m['memo'] as String?) ?? '',
          emoji: (m['emoji'] as String?) ?? '🐟',
          weather: (m['weather'] as String?) ?? '☀️ 맑음',
          count: int.tryParse(m['count']?.toString() ?? '1') ?? 1,
          createdFrom: 'map',
        ));
        existingIds.add(id);
      } catch (e) {
        debugPrint('지도 마이그레이션 실패: $e');
      }
    }

    // 통합 저장
    if (migrated.isNotEmpty) {
      final all = [...existing, ...migrated];
      await _saveAll(prefs, all);
      debugPrint('  ✓ ${migrated.length}건 마이그레이션됨 '
          '(도감: ${migrated.where((r) => r.createdFrom == 'encyclopedia').length}, '
          '지도: ${migrated.where((r) => r.createdFrom == 'map').length})');
    } else {
      debugPrint('  ✓ 마이그레이션할 데이터 없음 (신규 사용자)');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 조회
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 모든 기록 (최신순)
  Future<List<UnifiedCatchRecord>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kStorageKey) ?? <String>[];

    final result = <UnifiedCatchRecord>[];
    for (final raw in list) {
      try {
        result.add(UnifiedCatchRecord.decode(raw));
      } catch (e) {
        debugPrint('기록 파싱 실패: $e');
      }
    }

    result.sort((a, b) => b.catchTime.compareTo(a.catchTime));
    _cache = result;
    return List.unmodifiable(result);
  }

  /// 특정 어종의 기록 (최신순)
  Future<List<UnifiedCatchRecord>> getByFish(String fishName) async {
    final all = await getAll();
    return all.where((r) => r.fishName == fishName).toList();
  }

  /// 사진 있는 기록만 (도감 표시용)
  Future<List<UnifiedCatchRecord>> getWithPhoto() async {
    final all = await getAll();
    return all.where((r) => r.hasPhoto).toList();
  }

  /// 위치 있는 기록만 (지도 마커용)
  Future<List<UnifiedCatchRecord>> getWithLocation() async {
    final all = await getAll();
    return all.where((r) => r.hasLocation).toList();
  }

  /// 어종별 그룹핑 (도감용)
  Future<Map<String, List<UnifiedCatchRecord>>> groupByFish() async {
    final all = await getAll();
    final result = <String, List<UnifiedCatchRecord>>{};
    for (final r in all) {
      result.putIfAbsent(r.fishName, () => []).add(r);
    }
    return result;
  }

  /// 통계
  Future<Map<String, int>> getStats() async {
    final all = await getAll();
    return {
      'totalCount': all.length,
      'uniqueFishCount': all.map((r) => r.fishName).toSet().length,
      'totalFishCount': all.fold<int>(0, (s, r) => s + r.count),
      'uniqueSpotCount':
          all.where((r) => r.spotName != null).map((r) => r.spotName!).toSet().length,
    };
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 수정
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 새 기록 추가
  Future<void> add(UnifiedCatchRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await getAll()).toList();
    all.add(record);
    await _saveAll(prefs, all);

    // 사용자가 만든 새 어종이면 도감에도 자동 등록
    await _registerFishIfNew(prefs, record.fishName);
  }

  /// 기존 기록 업데이트 (ID 기준)
  Future<void> update(UnifiedCatchRecord updated) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await getAll()).toList();
    final idx = all.indexWhere((r) => r.id == updated.id);
    if (idx < 0) {
      debugPrint('업데이트 실패: ID ${updated.id} 없음');
      return;
    }
    all[idx] = updated;
    await _saveAll(prefs, all);
  }

  /// 기록 삭제 (ID 기준)
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await getAll()).where((r) => r.id != id).toList();
    await _saveAll(prefs, all);
  }

  /// 특정 어종의 모든 기록 삭제
  Future<void> deleteByFish(String fishName) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await getAll()).where((r) => r.fishName != fishName).toList();
    await _saveAll(prefs, all);

    // 사용자 추가 어종이면 목록에서도 제거
    final customFish = prefs.getStringList(_kCustomFishKey) ?? <String>[];
    if (customFish.contains(fishName)) {
      customFish.remove(fishName);
      await prefs.setStringList(_kCustomFishKey, customFish);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 어종 목록 (도감 + 자동 등록)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const List<String> defaultFishNames = [
    "감성돔", "광어", "우럭", "쥐노래미", "참돔",
    "벵에돔", "독가시치", "볼락", "노래미", "도다리",
  ];

  /// 사용자 추가 어종 목록 조회
  Future<List<String>> getCustomFishList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kCustomFishKey) ?? <String>[];
  }

  /// 사용자 어종 직접 추가 (수동)
  Future<void> addCustomFish(String fishName) async {
    if (fishName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await _registerFishIfNew(prefs, fishName);
  }

  /// 새 어종이면 자동 등록 (지도에서 어종 기록 시 호출)
  Future<void> _registerFishIfNew(
      SharedPreferences prefs, String fishName) async {
    if (defaultFishNames.contains(fishName)) return;

    final customFish = prefs.getStringList(_kCustomFishKey) ?? <String>[];
    if (customFish.contains(fishName)) return;

    customFish.add(fishName);
    await prefs.setStringList(_kCustomFishKey, customFish);
    debugPrint('새 어종 자동 등록: $fishName');
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 내부 헬퍼
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _saveAll(
      SharedPreferences prefs, List<UnifiedCatchRecord> records) async {
    // 최신순 정렬 후 저장
    records.sort((a, b) => b.catchTime.compareTo(a.catchTime));
    final raw = records.map((r) => r.encode()).toList();
    await prefs.setStringList(_kStorageKey, raw);

    // 캐시 갱신
    _cache = records;

    // 변경 알림
    _changeController.add(null);
  }

  /// 캐시 무효화 (외부에서 데이터 변경 시 강제 리프레시)
  void invalidateCache() {
    _cache = null;
  }

  /// 테스트/디버그용 — 모든 데이터 삭제
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
    _cache = null;
    _changeController.add(null);
  }

  void dispose() {
    _changeController.close();
  }
}