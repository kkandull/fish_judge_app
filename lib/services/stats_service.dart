import '../models/unified_catch_record.dart';

class StatsService {
  static UnifiedCatchRecord? biggestFish(
    List<UnifiedCatchRecord> records,
  ) {
    if (records.isEmpty) return null;

    records.sort((a, b) =>
        (b.lengthCm ?? 0).compareTo(a.lengthCm ?? 0));

    return records.first;
  }

  static Map<String, int> topFish(
    List<UnifiedCatchRecord> records,
  ) {
    final map = <String, int>{};

    for (final r in records) {
      map[r.fishName] = (map[r.fishName] ?? 0) + r.count;
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      for (final e in sorted.take(3))
        e.key: e.value,
    };
  }

  static double averageLength(
    List<UnifiedCatchRecord> records,
  ) {
    final valid =
        records.where((e) => e.lengthCm != null).toList();

    if (valid.isEmpty) return 0;

    final sum =
        valid.fold<double>(0, (s, e) => s + e.lengthCm!);

    return sum / valid.length;
  }
}