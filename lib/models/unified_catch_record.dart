import 'dart:convert';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 통합 조과 기록 모델 (Phase 3)
//
// 도감(EncyclopediaScreen)과 지도(MapScreen) 양쪽의 데이터 필드를 모두 포함하는
// 상위집합 모델. 사용처에 따라 일부 필드만 활용.
//
// 출처 추적:
//   - 'ai_scan': AI 판독으로 추가된 기록 (도감)
//   - 'encyclopedia': 도감에서 직접 추가
//   - 'map': 지도에서 조과 기록 (사진 없음)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UnifiedCatchRecord {
  final String id;                  // 고유 ID (millisecondsSinceEpoch)
  final String fishName;            // 어종
  final DateTime catchTime;         // 잡은 시각

  // ── 위치 정보 ─────────────────────────────────────────
  final double? latitude;           // 위도 (GPS)
  final double? longitude;          // 경도 (GPS)
  final String? locationName;       // 역지오코딩 결과 (예: "부산광역시 해운대구")
  final String? spotName;           // 사용자 지정 포인트 이름 (예: "해운대 방파제 끝단")

  // ── 사진 / 측정 ───────────────────────────────────────
  final String? imagePath;          // 로컬 사진 경로 (도감용)
  final double? lengthCm;
  final double? weightG;

  // ── 메모 / 장식 ───────────────────────────────────────
  final String memo;                // 메모 (기본 '')
  final String emoji;               // 어종 이모지 (기본 '🐟')
  final String weather;             // 날씨 (기본 '☀️ 맑음')
  final int count;                  // 마릿수 (기본 1)

  // ── 출처 ─────────────────────────────────────────────
  final String createdFrom;         // 'ai_scan' | 'encyclopedia' | 'map'

  const UnifiedCatchRecord({
    required this.id,
    required this.fishName,
    required this.catchTime,
    this.latitude,
    this.longitude,
    this.locationName,
    this.spotName,
    this.imagePath,
    this.lengthCm,
    this.weightG,
    this.memo = '',
    this.emoji = '🐟',
    this.weather = '☀️ 맑음',
    this.count = 1,
    this.createdFrom = 'unknown',
  });

  // ── 편의 메서드 ────────────────────────────────────────

  /// 사진 있는지 (도감에 표시할지 결정)
  bool get hasPhoto => imagePath != null && imagePath!.isNotEmpty;

  /// 위치 있는지 (지도에 마커 표시할지 결정)
  bool get hasLocation => latitude != null && longitude != null;

  /// 위치명 우선순위: spotName > locationName > 좌표
  String get displayLocation {
    if (spotName != null && spotName!.isNotEmpty) return spotName!;
    if (locationName != null && locationName!.isNotEmpty) return locationName!;
    if (hasLocation) {
      final lat = latitude!.toStringAsFixed(4);
      final lng = longitude!.toStringAsFixed(4);
      return '$lat°N $lng°E';
    }
    return '위치 정보 없음';
  }

  /// 날짜 문자열 (YYYY.MM.DD)
  String get dateStr =>
      '${catchTime.year}.${catchTime.month.toString().padLeft(2, '0')}.${catchTime.day.toString().padLeft(2, '0')}';

  // ── copyWith ──────────────────────────────────────────

  UnifiedCatchRecord copyWith({
    String? id,
    String? fishName,
    DateTime? catchTime,
    double? latitude,
    double? longitude,
    String? locationName,
    String? spotName,
    String? imagePath,
    double? lengthCm,
    double? weightG,
    String? memo,
    String? emoji,
    String? weather,
    int? count,
    String? createdFrom,
    bool clearImage = false,
    bool clearLocation = false,
  }) {
    return UnifiedCatchRecord(
      id: id ?? this.id,
      fishName: fishName ?? this.fishName,
      catchTime: catchTime ?? this.catchTime,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationName: clearLocation ? null : (locationName ?? this.locationName),
      spotName: spotName ?? this.spotName,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      lengthCm: lengthCm ?? this.lengthCm,
      weightG: weightG ?? this.weightG,
      memo: memo ?? this.memo,
      emoji: emoji ?? this.emoji,
      weather: weather ?? this.weather,
      count: count ?? this.count,
      createdFrom: createdFrom ?? this.createdFrom,
    );
  }

  // ── JSON 직렬화 ───────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'fishName': fishName,
        'catchTime': catchTime.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'spotName': spotName,
        'imagePath': imagePath,
        'lengthCm': lengthCm,
        'weightG': weightG,
        'memo': memo,
        'emoji': emoji,
        'weather': weather,
        'count': count,
        'createdFrom': createdFrom,
      };

  factory UnifiedCatchRecord.fromJson(Map<String, dynamic> j) {
    return UnifiedCatchRecord(
      id: j['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      fishName: j['fishName']?.toString() ?? '어종 미상',
      catchTime: j['catchTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(j['catchTime'] as int)
          : DateTime.now(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      locationName: j['locationName']?.toString(),
      spotName: j['spotName']?.toString(),
      imagePath: j['imagePath']?.toString(),
      lengthCm: (j['lengthCm'] as num?)?.toDouble(),
      weightG: (j['weightG'] as num?)?.toDouble(),
      memo: j['memo']?.toString() ?? '',
      emoji: j['emoji']?.toString() ?? '🐟',
      weather: j['weather']?.toString() ?? '☀️ 맑음',
      count: int.tryParse(j['count']?.toString() ?? '1') ?? 1,
      createdFrom: j['createdFrom']?.toString() ?? 'unknown',
    );
  }

  /// JSON 문자열로 직렬화 (저장용)
  String encode() => jsonEncode(toJson());

  /// JSON 문자열에서 복원 (불러오기용)
  static UnifiedCatchRecord decode(String raw) =>
      UnifiedCatchRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}