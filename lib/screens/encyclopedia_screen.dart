import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart'; // ← 추가: share_plus: ^9.0.0
import 'share_card.dart';

// ────────────────────────────────────────────────────────────────
// 📦 pubspec.yaml 에 아래 패키지를 추가하세요:
//
//   geolocator: ^11.0.0
//   http: ^1.2.1
//   image_picker: ^1.1.2
//   share_plus: ^9.0.0          ← 신규
//
// Android: AndroidManifest.xml 에 권한 추가
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//   <uses-permission android:name="android.permission.INTERNET"/>
//
// iOS: Info.plist 에 권한 추가
//   NSLocationWhenInUseUsageDescription
//   NSCameraUsageDescription
//   NSPhotoLibraryUsageDescription
// ────────────────────────────────────────────────────────────────

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 데이터 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 낚시 기록 1건 (이미지 경로 + 메타데이터 + 메모 + 크기/무게)
class CatchRecord {
  final String imagePath;
  final DateTime catchTime;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  // ── 신규 필드 ────────────────────────────────────────────────
  final String? memo;          // 자유 메모 (포인트, 미끼, 날씨 등)
  final double? lengthCm;      // 길이 (cm)
  final double? weightG;       // 무게 (g)

  CatchRecord({
    required this.imagePath,
    required this.catchTime,
    this.latitude,
    this.longitude,
    this.locationName,
    this.memo,
    this.lengthCm,
    this.weightG,
  });

  /// 메모/크기/무게를 업데이트한 복사본 반환
  CatchRecord copyWith({
    String? memo,
    double? lengthCm,
    double? weightG,
    bool clearMemo = false,
  }) {
    return CatchRecord(
      imagePath: imagePath,
      catchTime: catchTime,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      memo: clearMemo ? null : (memo ?? this.memo),
      lengthCm: lengthCm ?? this.lengthCm,
      weightG: weightG ?? this.weightG,
    );
  }

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'catchTime': catchTime.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'memo': memo,
        'lengthCm': lengthCm,
        'weightG': weightG,
      };

  factory CatchRecord.fromJson(Map<String, dynamic> json) => CatchRecord(
        imagePath: json['imagePath'] as String,
        catchTime:
            DateTime.fromMillisecondsSinceEpoch(json['catchTime'] as int),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationName: json['locationName'] as String?,
        memo: json['memo'] as String?,
        lengthCm: (json['lengthCm'] as num?)?.toDouble(),
        weightG: (json['weightG'] as num?)?.toDouble(),
      );

  factory CatchRecord.fromLegacyPath(String path) {
    int millis = 0;
    try {
      millis = int.parse(p.basename(path).split('_')[0]);
    } catch (_) {}
    return CatchRecord(
      imagePath: path,
      catchTime: millis > 0
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 GPS + 역지오코딩 서비스
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&accept-language=ko',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'FishingApp/1.0'})
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final parts = [
            addr['city'] ?? addr['county'] ?? addr['state'],
            addr['suburb'] ?? addr['town'] ?? addr['village'],
          ].whereType<String>().toList();
          return parts.isNotEmpty ? parts.join(' ') : data['display_name'];
        }
      }
    } catch (_) {}
    return null;
  }

  static String formatCoords(double lat, double lon) {
    String latStr =
        '${lat.abs().toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'}';
    String lonStr =
        '${lon.abs().toStringAsFixed(4)}°${lon >= 0 ? 'E' : 'W'}';
    return '$latStr $lonStr';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 메인 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class EncyclopediaScreen extends StatefulWidget {
  final File? capturedImage;
  final String? targetFish;

  const EncyclopediaScreen({super.key, this.capturedImage, this.targetFish});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  // ── 장비 데이터 ──────────────────────────────────────────────
  final List<Map<String, String>> commonGear = [
    {
      "name": "낚시대+릴",
      "url":
          "https://www.coupang.com/np/search?q=JAHCHO 캠핑 바다낚시 입문자용 다용도 미니 낚시대 세트"
    },
    {
      "name": "두레박",
      "url":
          "https://www.coupang.com/np/search?q=낚시+잇츠온 EVA 접이식 두레박"
    },
    {
      "name": "가위, 집개",
      "url":
          "https://www.coupang.com/np/search?q=다용도 스테인리스 낚시 가위 겸용 집게 컨트롤 플라이어"
    },
  ];

  // ── 기본 어종 ─────────────────────────────────────────────────
  final List<String> defaultFishNames = [
    "감성돔",
    "광어",
    "우럭",
    "쥐노래미",
    "참돔",
  ];

  List<String> customFishNames = [];
  Map<String, List<CatchRecord>> recordMap = {};
  bool _isLoading = true;

  List<String> get allFishNames => [...defaultFishNames, ...customFishNames];

  String _recordsKey(String fishName) => 'records_$fishName';

  // ── 개인 최대어 키 ────────────────────────────────────────────
  String _pbLengthKey(String fishName) => 'pb_length_$fishName';
  String _pbWeightKey(String fishName) => 'pb_weight_$fishName';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    customFishNames = prefs.getStringList('custom_fish_list') ?? [];

    for (final name in allFishNames) {
      recordMap[name] = await _loadRecords(prefs, name);
    }

    if (mounted) setState(() => _isLoading = false);

    if (widget.targetFish != null && widget.capturedImage != null) {
      if (allFishNames.contains(widget.targetFish)) {
        await _addRecord(widget.targetFish!, widget.capturedImage!, prefs);
      }
    }
  }

  Future<List<CatchRecord>> _loadRecords(
      SharedPreferences prefs, String fishName) async {
    final jsonStr = prefs.getString(_recordsKey(fishName));
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list
            .map((e) => CatchRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final legacy = prefs.getStringList(fishName);
    if (legacy != null && legacy.isNotEmpty) {
      return legacy.map(CatchRecord.fromLegacyPath).toList();
    }
    return [];
  }

  Future<void> _saveRecords(
      SharedPreferences prefs, String fishName) async {
    final list = recordMap[fishName] ?? [];
    await prefs.setString(
      _recordsKey(fishName),
      jsonEncode(list.map((r) => r.toJson()).toList()),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 기록 추가
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _addRecord(
    String fishName,
    File tempFile,
    SharedPreferences prefs,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fishDir = Directory('${directory.path}/$fishName');
      if (!await fishDir.exists()) await fishDir.create(recursive: true);

      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${p.basename(tempFile.path)}";
      final permanentFile =
          await tempFile.copy('${fishDir.path}/$fileName');

      final position = await LocationService.getCurrentPosition();
      String? locationName;
      if (position != null) {
        locationName = await LocationService.reverseGeocode(
          position.latitude,
          position.longitude,
        );
      }

      final record = CatchRecord(
        imagePath: permanentFile.path,
        catchTime: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationName: locationName,
      );

      final currentList = recordMap[fishName] ?? [];
      if (!currentList.any((r) => r.imagePath == permanentFile.path)) {
        currentList.add(record);
        recordMap[fishName] = currentList;
        await _saveRecords(prefs, fishName);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("기록 저장 오류: $e");
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 메모 + 크기/무게 편집 (신규)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _showEditMemoDialog(
      String fishName, CatchRecord record) async {
    final memoCtrl =
        TextEditingController(text: record.memo ?? '');
    final lengthCtrl = TextEditingController(
        text: record.lengthCm != null
            ? record.lengthCm!.toStringAsFixed(1)
            : '');
    final weightCtrl = TextEditingController(
        text: record.weightG != null
            ? record.weightG!.toStringAsFixed(0)
            : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          "기록 메모 편집",
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1976D2)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 자유 메모
              TextField(
                controller: memoCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '메모',
                  hintText: '포인트, 미끼 종류, 날씨 등 자유롭게 입력',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.edit_note,
                      color: Color(0xFF1976D2)),
                ),
              ),
              const SizedBox(height: 14),
              // 길이
              TextField(
                controller: lengthCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '길이 (cm)',
                  hintText: '예: 45.5',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      const Icon(Icons.straighten, color: Color(0xFF1976D2)),
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 14),
              // 무게
              TextField(
                controller: weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '무게 (g)',
                  hintText: '예: 1200',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.monitor_weight_outlined,
                      color: Color(0xFF1976D2)),
                  suffixText: 'g',
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("취소"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveRecordEdits(
                      fishName,
                      record,
                      memoCtrl.text.trim().isEmpty
                          ? null
                          : memoCtrl.text.trim(),
                      double.tryParse(lengthCtrl.text),
                      double.tryParse(weightCtrl.text),
                    );
                  },
                  child: const Text("저장",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecordEdits(
    String fishName,
    CatchRecord original,
    String? memo,
    double? lengthCm,
    double? weightG,
  ) async {
    final list = recordMap[fishName] ?? [];
    final idx =
        list.indexWhere((r) => r.imagePath == original.imagePath);
    if (idx < 0) return;

    final updated = CatchRecord(
      imagePath: original.imagePath,
      catchTime: original.catchTime,
      latitude: original.latitude,
      longitude: original.longitude,
      locationName: original.locationName,
      memo: memo,
      lengthCm: lengthCm,
      weightG: weightG,
    );
    list[idx] = updated;
    recordMap[fishName] = list;

    final prefs = await SharedPreferences.getInstance();
    await _saveRecords(prefs, fishName);

    // ── 개인 최대어 갱신 체크 ─────────────────────────────────
    bool newPB = false;
    if (lengthCm != null) {
      final prevLen = prefs.getDouble(_pbLengthKey(fishName)) ?? 0.0;
      if (lengthCm > prevLen) {
        await prefs.setDouble(_pbLengthKey(fishName), lengthCm);
        newPB = true;
      }
    }
    if (weightG != null) {
      final prevWt = prefs.getDouble(_pbWeightKey(fishName)) ?? 0.0;
      if (weightG > prevWt) {
        await prefs.setDouble(_pbWeightKey(fishName), weightG);
        newPB = true;
      }
    }

    if (mounted) {
      setState(() {});
      if (newPB) {
        _showPBAlert(fishName, lengthCm, weightG);
      }
    }
  }

  void _showPBAlert(String fishName, double? len, double? wt) {
    String detail = '';
    if (len != null) detail += '길이 ${len.toStringAsFixed(1)} cm';
    if (len != null && wt != null) detail += '  •  ';
    if (wt != null) {
      detail += wt >= 1000
          ? '무게 ${(wt / 1000).toStringAsFixed(2)} kg'
          : '무게 ${wt.toStringAsFixed(0)} g';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF6F00),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Text("🏆", style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$fishName 개인 최대어 갱신!",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14)),
                  if (detail.isNotEmpty)
                    Text(detail,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 사용자 어종 추가/삭제
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _showAddCustomFishDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    File? pickedImage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              "새 어종 추가",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1976D2)),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '어종 이름',
                      hintText: '예: 볼락, 놀래기...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.set_meal, color: Color(0xFF1976D2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setInner(() => pickedImage = File(picked.path));
                      }
                    },
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.4),
                            width: 1.5),
                      ),
                      child: pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(pickedImage!,
                                  fit: BoxFit.cover, width: double.infinity),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 30, color: Colors.blueAccent),
                                SizedBox(height: 6),
                                Text("사진 선택 (선택사항)",
                                    style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 13)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("취소"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        await _addCustomFish(name, pickedImage);
                      },
                      child: const Text("추가",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _addCustomFish(String fishName, File? image) async {
    final prefs = await SharedPreferences.getInstance();
    if (allFishNames.contains(fishName)) {
      if (image != null) await _addRecord(fishName, image, prefs);
      return;
    }
    customFishNames.add(fishName);
    recordMap[fishName] = [];
    await prefs.setStringList('custom_fish_list', customFishNames);
    if (image != null) await _addRecord(fishName, image, prefs);
    if (mounted) setState(() {});
  }

  Future<void> _deleteFish(String fishName) async {
    final records = recordMap[fishName] ?? [];
    for (final r in records) {
      try {
        final file = File(r.imagePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fishDir = Directory('${directory.path}/$fishName');
      if (await fishDir.exists()) await fishDir.delete(recursive: true);
    } catch (_) {}
    customFishNames.remove(fishName);
    recordMap.remove(fishName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_fish_list', customFishNames);
    await prefs.remove('records_$fishName');
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteFish(
      BuildContext context, String fishName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("어종 삭제"),
        content: Text(
            "'$fishName' 어종과 관련된\n모든 기록·사진을 삭제할까요?\n삭제하면 복구할 수 없습니다."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteFish(fishName);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 사진 삭제
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _deleteRecord(
      String fishName, CatchRecord record) async {
    try {
      final file = File(record.imagePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint("파일 삭제 오류: $e");
    }
    final list = recordMap[fishName] ?? [];
    list.removeWhere((r) => r.imagePath == record.imagePath);
    recordMap[fishName] = list;
    final prefs = await SharedPreferences.getInstance();
    await _saveRecords(prefs, fishName);
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteRecord(
      BuildContext context, String fishName, CatchRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("사진 삭제"),
        content: const Text("이 사진 기록을 삭제할까요?\n삭제하면 복구할 수 없습니다."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteRecord(fishName, record);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 사진 추가
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _addPhotoToFish(String fishName) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await _addRecord(fishName, File(picked.path), prefs);
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("사진 추가"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
              title: const Text("카메라로 촬영"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1976D2)),
              title: const Text("갤러리에서 선택"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 상세 팝업 (메모 + 크기/무게 포함)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String _formatDate(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} "
        "$amPm $hour:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _locationText(CatchRecord record) {
    if (record.locationName != null) return record.locationName!;
    if (record.latitude != null && record.longitude != null) {
      return LocationService.formatCoords(
          record.latitude!, record.longitude!);
    }
    return "위치 정보 없음";
  }

  String _weightLabel(double g) =>
      g >= 1000 ? '${(g / 1000).toStringAsFixed(2)} kg' : '${g.toStringAsFixed(0)} g';

  void _showFishDetailPopup(
      BuildContext context, String fishName, CatchRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fishName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1976D2)),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(record.imagePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 230,
                    errorBuilder: (_, __, ___) => Container(
                      height: 230,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 포획 일시
                _InfoTile(
                  icon: Icons.calendar_month_rounded,
                  label: "포획 일시",
                  value: _formatDate(record.catchTime),
                ),
                const SizedBox(height: 8),

                // 포획 위치
                _InfoTile(
                  icon: record.latitude != null
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  label: "포획 위치",
                  value: _locationText(record),
                  iconColor: record.latitude != null
                      ? const Color(0xFF1976D2)
                      : Colors.grey,
                ),

                // 크기/무게
                if (record.lengthCm != null || record.weightG != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (record.lengthCm != null)
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.straighten,
                            label: "길이",
                            value:
                                "${record.lengthCm!.toStringAsFixed(1)} cm",
                          ),
                        ),
                      if (record.lengthCm != null &&
                          record.weightG != null)
                        const SizedBox(width: 8),
                      if (record.weightG != null)
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.monitor_weight_outlined,
                            label: "무게",
                            value: _weightLabel(record.weightG!),
                          ),
                        ),
                    ],
                  ),
                ],

                // 메모
                if (record.memo != null && record.memo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoTile(
                    icon: Icons.sticky_note_2_outlined,
                    label: "메모",
                    value: record.memo!,
                  ),
                ],

                const SizedBox(height: 18),

                // 버튼 행: 메모 편집 / 공유 / 닫기
                Row(
                  children: [
                    // 메모 편집
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(
                              color: Color(0xFF1976D2)),
                        ),
                        icon: const Icon(Icons.edit,
                            color: Color(0xFF1976D2), size: 18),
                        label: const Text("메모",
                            style: TextStyle(color: Color(0xFF1976D2))),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showEditMemoDialog(fishName, record);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 공유
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.green),
                        ),
                        icon: const Icon(Icons.share,
                            color: Colors.green, size: 18),
                        label: const Text("공유",
                            style: TextStyle(color: Colors.green)),
                        onPressed: () =>
                            _shareRecord(fishName, record),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 닫기
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B3A55),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('닫기',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 공유 (신규) — share_plus 사용
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _shareRecord(String fishName, CatchRecord record) async {
  await ShareCardUtil.shareRecord(
    context,
    fishName: fishName,
    record: CatchRecordForShare(
      imagePath: record.imagePath,
      catchTime: record.catchTime,
      locationName: record.locationName,
      latitude: record.latitude,
      longitude: record.longitude,
      lengthCm: record.lengthCm,
      weightG: record.weightG,
      memo: record.memo,
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 조황 일지 화면 열기 (신규)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _openJournal() {
    // 전체 기록을 날짜순으로 정렬해 전달
    final allRecords = <_JournalEntry>[];
    for (final fish in allFishNames) {
      for (final r in recordMap[fish] ?? []) {
        allRecords.add(_JournalEntry(fishName: fish, record: r));
      }
    }
    allRecords.sort((a, b) =>
        b.record.catchTime.compareTo(a.record.catchTime));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JournalScreen(
          entries: allRecords,
          onShare: _shareRecord,
          onEdit: _showEditMemoDialog,
        ),
      ),
    );
  }

  // ── URL 런처 ──────────────────────────────────────────────────
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url : $e");
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📌 UI 빌드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('내 도감 및 장비 추천',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 📋 조황 일지 버튼
          IconButton(
            icon: const Icon(Icons.menu_book_rounded,
                color: Color(0xFF1976D2)),
            tooltip: "조황 일지",
            onPressed: _openJournal,
          ),
          // 수집 통계 뱃지
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _StatsBadge(
                total: allFishNames.length,
                collected: allFishNames
                    .where((n) => (recordMap[n]?.isNotEmpty ?? false))
                    .length,
              ),
            ),
          ),
        ],
      ),

      // ── 하단 고정 버튼 ────────────────────────────────────────
      bottomSheet: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 16, // ← 여백 충분히
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _showAddCustomFishDialog,
          icon: const Icon(Icons.add, color: Colors.white, size: 22),
          label: const Text(
            "어종 추가",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),

      body: ListView(
        // bottomSheet 높이(버튼 56 + 패딩) + 추가 여백
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 120, // ← 충분한 하단 여백
        ),
        children: [
          // ── 필수 공용 장비 ─────────────────────────────────────
          const Text("필수 공용 장비",
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: commonGear.length,
              itemBuilder: (context, index) => Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onPressed: () => _launchURL(commonGear[index]['url']),
                  child: Text(
                    commonGear[index]['name']!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // ── 섹션 헤더 ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("어종별 수집 현황",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                "${allFishNames.where((n) => recordMap[n]?.isNotEmpty ?? false).length} / ${allFishNames.length} 종",
                style: const TextStyle(
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 어종 카드 리스트 ──────────────────────────────────
          ...allFishNames.map((name) {
            final records = recordMap[name] ?? [];
            final isCustom = customFishNames.contains(name);
            return _FishCard(
              fishName: name,
              records: records,
              isCustom: isCustom,
              onPhotoAdd: () => _addPhotoToFish(name),
              onRecordTap: (record) =>
                  _showFishDetailPopup(context, name, record),
              onRecordDelete: (record) =>
                  _confirmDeleteRecord(context, name, record),
              onFishDelete: isCustom
                  ? () => _confirmDeleteFish(context, name)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 조황 일지 화면 (신규)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _JournalEntry {
  final String fishName;
  final CatchRecord record;
  _JournalEntry({required this.fishName, required this.record});
}

class _JournalScreen extends StatelessWidget {
  final List<_JournalEntry> entries;
  final Future<void> Function(String, CatchRecord) onShare;
  final Future<void> Function(String, CatchRecord) onEdit;

  const _JournalScreen({
    required this.entries,
    required this.onShare,
    required this.onEdit,
  });

  String _dayKey(DateTime dt) =>
      "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}";

  String _timeStr(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return "$amPm $h:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _weightLabel(double g) =>
      g >= 1000 ? '${(g / 1000).toStringAsFixed(2)} kg' : '${g.toStringAsFixed(0)} g';

  @override
  Widget build(BuildContext context) {
    // 날짜별로 그룹핑
    final Map<String, List<_JournalEntry>> grouped = {};
    for (final e in entries) {
      final key = _dayKey(e.record.catchTime);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final days = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('조황 일지',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phishing, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("아직 기록이 없습니다.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: days.length,
              itemBuilder: (context, dayIdx) {
                final day = days[dayIdx];
                final dayEntries = grouped[day]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 헤더
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(day,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Text("${dayEntries.length}마리",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),

                    // 타임라인 항목들
                    ...dayEntries.asMap().entries.map((entry) {
                      final isLast =
                          entry.key == dayEntries.length - 1;
                      final e = entry.value;
                      final r = e.record;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 타임라인 라인 + 원
                            SizedBox(
                              width: 32,
                              child: Column(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1976D2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // 카드
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    bottom: isLast ? 24 : 14),
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 썸네일
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(r.imagePath),
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 70,
                                              height: 70,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  size: 28),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // 텍스트 정보
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(e.fishName,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15)),
                                                  const Spacer(),
                                                  Text(_timeStr(r.catchTime),
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey.shade500,
                                                          fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (r.locationName != null)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.location_on,
                                                        size: 13,
                                                        color: Colors.blueGrey),
                                                    const SizedBox(width: 2),
                                                    Flexible(
                                                      child: Text(
                                                          r.locationName!,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .blueGrey),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis),
                                                    ),
                                                  ],
                                                ),
                                              if (r.lengthCm != null ||
                                                  r.weightG != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 3),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    children: [
                                                      if (r.lengthCm != null)
                                                        _Chip(
                                                          icon: Icons.straighten,
                                                          label:
                                                              "${r.lengthCm!.toStringAsFixed(1)} cm",
                                                        ),
                                                      if (r.weightG != null)
                                                        _Chip(
                                                          icon: Icons
                                                              .monitor_weight_outlined,
                                                          label: _weightLabel(
                                                              r.weightG!),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              if (r.memo != null &&
                                                  r.memo!.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    r.memo!,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54,
                                                        fontStyle:
                                                            FontStyle.italic),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // 공유 버튼
                                        IconButton(
                                          icon: const Icon(Icons.share,
                                              size: 18,
                                              color: Colors.blueGrey),
                                          tooltip: "공유",
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              onShare(e.fishName, r),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 보조 위젯들
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StatsBadge extends StatelessWidget {
  final int total;
  final int collected;
  const _StatsBadge({required this.total, required this.collected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "🎣 $collected/$total",
        style: const TextStyle(
            color: Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
            fontSize: 13),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = const Color(0xFF1976D2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 조황 일지용 소형 정보 칩
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF1976D2)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FishCard extends StatelessWidget {
  final String fishName;
  final List<CatchRecord> records;
  final bool isCustom;
  final VoidCallback onPhotoAdd;
  final void Function(CatchRecord) onRecordTap;
  final void Function(CatchRecord) onRecordDelete;
  final VoidCallback? onFishDelete;

  const _FishCard({
    required this.fishName,
    required this.records,
    required this.isCustom,
    required this.onPhotoAdd,
    required this.onRecordTap,
    required this.onRecordDelete,
    this.onFishDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCollected = records.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCollected)
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: records.length,
                itemBuilder: (context, idx) {
                  final record = records[idx];
                  return GestureDetector(
                    onTap: () => onRecordTap(record),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(record.imagePath),
                              width: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 220,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image)),
                            ),
                          ),
                          // GPS 아이콘
                          if (record.latitude != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.location_on,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          // 메모 아이콘 (메모 있을 때)
                          if (record.memo != null &&
                              record.memo!.isNotEmpty)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700
                                      .withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.sticky_note_2,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          // 삭제 버튼
                          Positioned(
                            top: 6,
                            left: 6,
                            child: GestureDetector(
                              onTap: () => onRecordDelete(record),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 150,
              color: Colors.grey.shade300,
              child: const Center(
                child: Text("미수집 어종",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          ListTile(
            title: Text(fishName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isCollected
                ? "수집 완료 (${records.length}마리)"
                : "미수집"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: Color(0xFF1976D2)),
                  tooltip: "사진 추가",
                  onPressed: onPhotoAdd,
                ),
                if (onFishDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: "어종 삭제",
                    onPressed: onFishDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}