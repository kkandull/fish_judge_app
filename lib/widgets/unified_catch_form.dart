import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/unified_catch_record.dart';
import '../services/catch_record_repository.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 통합 조과 입력 폼 (Phase 3.5)
//
// 한 폼에서 모든 정보 입력 → 도감 + 지도 양쪽 자동 반영
// 호출 시나리오:
//   1) 지도 "조과 기록" 버튼: prefilledFishName=null, 어종 직접 입력
//   2) 도감 "사진 추가" 버튼: prefilledFishName=어종명, 어종 잠금
//   3) AI 판독 결과: prefilledFishName + prefilledImage 모두 전달
//
// 사용법:
//   final saved = await showUnifiedCatchForm(
//     context,
//     prefilledFishName: '감성돔',
//     prefilledImage: File('/path/...'),
//   );
//   if (saved) { /* 저장 성공 */ }
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const Color _kPrimary = Color(0xFF03C75A);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kCard = Colors.white;
const Color _kRed = Color(0xFFFF4B4B);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);

// 어종별 기본 이모지
const Map<String, String> _kFishEmoji = {
  '감성돔': '🐟',
  '광어': '🐟',
  '우럭': '🐟',
  '쥐노래미': '🐟',
  '참돔': '🐠',
  '벵에돔': '🐟',
  '독가시치': '🐡',
  '볼락': '🐟',
  '노래미': '🐟',
  '도다리': '🐟',
  '복어': '🐡',
};

/// 통합 폼 표시 (외부에서 호출)
/// 반환값: true = 저장됨, false/null = 취소됨
Future<bool> showUnifiedCatchForm(
  BuildContext context, {
  String? prefilledFishName,
  File? prefilledImage,
  String createdFrom = 'unified_form',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) => _UnifiedCatchFormSheet(
      prefilledFishName: prefilledFishName,
      prefilledImage: prefilledImage,
      createdFrom: createdFrom,
    ),
  );
  return result ?? false;
}

class _UnifiedCatchFormSheet extends StatefulWidget {
  final String? prefilledFishName;
  final File? prefilledImage;
  final String createdFrom;

  const _UnifiedCatchFormSheet({
    this.prefilledFishName,
    this.prefilledImage,
    required this.createdFrom,
  });

  @override
  State<_UnifiedCatchFormSheet> createState() => _UnifiedCatchFormSheetState();
}

class _UnifiedCatchFormSheetState extends State<_UnifiedCatchFormSheet> {
  late TextEditingController _fishCtrl;
  late TextEditingController _spotCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _memoCtrl;

  File? _pickedImage;
  String _emoji = '🐟';
  String _weather = '☀️ 맑음';
  int _count = 1;
  bool _saving = false;

  // GPS 자동 수집
  Position? _position;
  String? _locationName;
  bool _gpsLoading = false;

  final _emojis = ['🐟', '🐠', '🦈', '🐡', '🦐', '🦑', '🦀', '🐙'];
  final _weathers = ['☀️ 맑음', '⛅ 구름', '🌧️ 비', '💨 바람', '🌙 야간'];

  bool get _fishLocked => widget.prefilledFishName != null;

  @override
  void initState() {
    super.initState();
    _fishCtrl = TextEditingController(text: widget.prefilledFishName ?? '');
    _spotCtrl = TextEditingController();
    _lengthCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
    _pickedImage = widget.prefilledImage;
    if (widget.prefilledFishName != null) {
      _emoji = _kFishEmoji[widget.prefilledFishName!] ?? '🐟';
    }
    _fetchGps();
  }

  @override
  void dispose() {
    _fishCtrl.dispose();
    _spotCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGps() async {
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _gpsLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );

      // 역지오코딩
      String? locName;
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=ko',
        );
        final res = await http
            .get(uri, headers: {'User-Agent': 'FishingApp/1.0'})
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final parts = [
              addr['city'] ?? addr['county'] ?? addr['state'],
              addr['suburb'] ?? addr['town'] ?? addr['village'],
            ].whereType<String>().toList();
            locName = parts.isNotEmpty ? parts.join(' ') : data['display_name'];
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _position = pos;
          _locationName = locName;
          _gpsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kPrimary),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kPrimary),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_pickedImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _kRed),
                title: const Text('사진 제거', style: TextStyle(color: _kRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _pickedImage = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  /// 사진을 영구 위치로 복사
  Future<String?> _persistImage(String fishName) async {
    if (_pickedImage == null) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fishDir = Directory('${directory.path}/$fishName');
      if (!await fishDir.exists()) await fishDir.create(recursive: true);
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${p.basename(_pickedImage!.path)}";
      final permanent = await _pickedImage!.copy('${fishDir.path}/$fileName');
      return permanent.path;
    } catch (e) {
      debugPrint('사진 저장 실패: $e');
      return null;
    }
  }

  Future<void> _save() async {
    final fishName = _fishCtrl.text.trim();
    if (fishName.isEmpty) {
      _showSnack('어종 이름을 입력하세요', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final imagePath = await _persistImage(fishName);
      final record = UnifiedCatchRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fishName: fishName,
        catchTime: DateTime.now(),
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        locationName: _locationName,
        spotName: _spotCtrl.text.trim().isEmpty ? null : _spotCtrl.text.trim(),
        imagePath: imagePath,
        lengthCm: double.tryParse(_lengthCtrl.text),
        weightG: double.tryParse(_weightCtrl.text),
        memo: _memoCtrl.text.trim(),
        emoji: _emoji,
        weather: _weather,
        count: _count,
        createdFrom: widget.createdFrom,
      );

      await CatchRecordRepository.instance.add(record);
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('저장 실패: $e', isError: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? _kRed : _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  _buildPhotoPicker(),
                  const SizedBox(height: 20),
                  _buildFishField(),
                  const SizedBox(height: 16),
                  _buildEmojiSelector(),
                  const SizedBox(height: 16),
                  _buildSpotField(),
                  const SizedBox(height: 16),
                  _buildSizeFields(),
                  const SizedBox(height: 16),
                  _buildCountSelector(),
                  const SizedBox(height: 16),
                  _buildWeatherSelector(),
                  const SizedBox(height: 16),
                  _buildMemoField(),
                  const SizedBox(height: 16),
                  _buildGpsIndicator(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_location_alt_outlined,
                    color: _kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('조과 기록',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('도감과 지도에 함께 저장돼요',
                        style: TextStyle(fontSize: 11, color: _kSub)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pickedImage != null ? _kPrimary : _kBorder,
            width: _pickedImage != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _pickedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_pickedImage!, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('변경',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60, height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: _kPrimary, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text('사진 추가',
                      style: TextStyle(
                          color: _kNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('카메라 또는 갤러리 (선택)',
                      style: TextStyle(color: _kSub, fontSize: 11)),
                ],
              ),
      ),
    );
  }

  Widget _buildFishField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('어종 *'),
        const SizedBox(height: 8),
        TextField(
          controller: _fishCtrl,
          enabled: !_fishLocked,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy),
          decoration: InputDecoration(
            hintText: '예: 감성돔, 광어',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor:
                _fishLocked ? _kPrimary.withOpacity(0.08) : Colors.grey[50],
            prefixIcon: Icon(
              _fishLocked ? Icons.lock : Icons.set_meal,
              color: _kPrimary, size: 18,
            ),
            suffixIcon: _fishLocked
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child:
                        Icon(Icons.check_circle, color: _kPrimary, size: 18),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: _fieldBorder(_fishLocked),
            enabledBorder: _fieldBorder(_fishLocked),
            focusedBorder: _fieldBorder(true),
            disabledBorder: _fieldBorder(true),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(bool highlighted) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: highlighted ? _kPrimary : _kBorder,
          width: highlighted ? 1.5 : 1,
        ),
      );

  Widget _buildEmojiSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('이모지'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _emojis.map((e) {
              final sel = _emoji == e;
              return GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  width: 48, height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel
                        ? _kPrimary.withOpacity(0.12)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _kPrimary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpotField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('포인트 이름 (선택)'),
        const SizedBox(height: 8),
        TextField(
          controller: _spotCtrl,
          style: const TextStyle(fontSize: 14, color: _kNavy),
          decoration: InputDecoration(
            hintText: '예: 해운대 방파제 끝단',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon:
                const Icon(Icons.place_outlined, color: _kPrimary, size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _fieldBorder(false),
            enabledBorder: _fieldBorder(false),
            focusedBorder: _fieldBorder(true),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeFields() {
    return Row(
      children: [
        Expanded(child: _buildSizeField(_lengthCtrl, '길이 (cm)', '45.5', 'cm', Icons.straighten)),
        const SizedBox(width: 12),
        Expanded(child: _buildSizeField(_weightCtrl, '무게 (g)', '1200', 'g', Icons.monitor_weight_outlined)),
      ],
    );
  }

  Widget _buildSizeField(TextEditingController ctrl, String label, String hint,
      String suffix, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, color: _kNavy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: Icon(icon, color: _kPrimary, size: 18),
            suffixText: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _fieldBorder(false),
            enabledBorder: _fieldBorder(false),
            focusedBorder: _fieldBorder(true),
          ),
        ),
      ],
    );
  }

  Widget _buildCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('마릿수'),
        const SizedBox(height: 8),
        Row(
          children: [
            _countBtn('−', () => setState(() {
                  if (_count > 1) _count--;
                })),
            const SizedBox(width: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_count 마리',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kNavy)),
            ),
            const SizedBox(width: 14),
            _countBtn('+', () => setState(() => _count++)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('날씨'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _weathers.map((w) {
            final sel = _weather == w;
            return GestureDetector(
              onTap: () => setState(() => _weather = w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kPrimary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(w,
                    style: TextStyle(
                      color: sel ? Colors.white : _kSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMemoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('메모 (선택)'),
        const SizedBox(height: 8),
        TextField(
          controller: _memoCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: _kNavy),
          decoration: InputDecoration(
            hintText: '조황, 미끼, 팁 등 자유롭게',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: _fieldBorder(false),
            enabledBorder: _fieldBorder(false),
            focusedBorder: _fieldBorder(true),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsIndicator() {
    final hasGps = _position != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasGps
            ? _kPrimary.withOpacity(0.06)
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasGps
                ? _kPrimary.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          if (_gpsLoading)
            const SizedBox(
              width: 15, height: 15,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kPrimary),
            )
          else
            Icon(
              hasGps ? Icons.gps_fixed : Icons.gps_off,
              color: hasGps ? _kPrimary : Colors.orange,
              size: 15,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gpsLoading
                  ? 'GPS 위치 가져오는 중...'
                  : hasGps
                      ? 'GPS 자동 저장${_locationName != null ? ' · $_locationName' : ''}'
                      : 'GPS 사용 불가 (권한 거부 또는 신호 약함)',
              style: TextStyle(
                fontSize: 11,
                color: hasGps ? _kPrimary : Colors.orange.shade800,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text('저장하기',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kSub,
        letterSpacing: 0.5,
      ));

  Widget _countBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
        ),
      );
}