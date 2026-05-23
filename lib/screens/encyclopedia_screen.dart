import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'share_card.dart';
import '../models/unified_catch_record.dart';
import '../services/catch_record_repository.dart';
import '../widgets/unified_catch_form.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 필수 장비 데이터
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const List<Map<String, dynamic>> kCommonGear = [
  {
    "name": "낚시대 + 릴 세트",
    "icon": "🎣",
    "color": Color(0xFF1976D2),
    "description": "입문자용 다용도 미니 낚시대 세트. 캠핑·바다낚시에 두루 사용 가능.",
    "url": "https://www.coupang.com/np/search?q=JAHCHO 캠핑 바다낚시 입문자용 다용도 미니 낚시대 세트",
  },
  {
    "name": "두레박",
    "icon": "🪣",
    "color": Color(0xFF00C2A8),
    "description": "EVA 접이식 두레박. 미끼 물 보관, 잡은 고기 임시 보관에 필수.",
    "url": "https://www.coupang.com/np/search?q=낚시+잇츠온 EVA 접이식 두레박",
  },
  {
    "name": "가위·집게",
    "icon": "✂️",
    "color": Color(0xFFFF8A65),
    "description": "다용도 스테인리스 낚시 가위 겸용 집게. 라인 자르기·미끼 잡기 등 만능.",
    "url": "https://www.coupang.com/np/search?q=다용도 스테인리스 낚시 가위 겸용 집게 컨트롤 플라이어",
  },
];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 메인 도감 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class EncyclopediaScreen extends StatefulWidget {
  final File? capturedImage;
  final String? targetFish;

  const EncyclopediaScreen({super.key, this.capturedImage, this.targetFish});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  final repo = CatchRecordRepository.instance;
  StreamSubscription? _changeSub;

  List<String> customFishNames = [];
  Map<String, List<UnifiedCatchRecord>> recordMap = {};
  bool _isLoading = true;

  List<String> get allFishNames =>
      [...CatchRecordRepository.defaultFishNames, ...customFishNames];

  String _pbLengthKey(String f) => 'pb_length_$f';
  String _pbWeightKey(String f) => 'pb_weight_$f';

  @override
  void initState() {
    super.initState();
    _loadData();
    _changeSub = repo.changes.listen((_) {
      if (mounted) _loadData(silent: true);
    });

    // AI 판독에서 사진+어종 받은 경우 → 통합 폼 자동 띄움
    if (widget.targetFish != null && widget.capturedImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addRecordFromAi(widget.targetFish!, widget.capturedImage!);
      });
    }
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    customFishNames = await repo.getCustomFishList();
    final grouped = await repo.groupByFish();
    recordMap.clear();
    for (final name in allFishNames) {
      recordMap[name] = grouped[name] ?? [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ━━━ 통합 폼 호출 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// AI 판독 결과로 통합 폼 호출 (사진 + 어종 자동 채워짐)
  Future<void> _addRecordFromAi(String fishName, File tempFile) async {
    await showUnifiedCatchForm(
      context,
      prefilledFishName: fishName,
      prefilledImage: tempFile,
      createdFrom: 'ai_scan',
    );
  }

  /// 도감 "사진 추가" 버튼으로 통합 폼 호출 (어종 자동 채워짐)
  Future<void> _addPhotoToFish(String fishName) async {
    await showUnifiedCatchForm(
      context,
      prefilledFishName: fishName,
      createdFrom: 'encyclopedia',
    );
  }

  // ━━━ 메모/측정 편집 (기존 기록 수정) ━━━━━━━━━━━━━━━━━━

  Future<void> _showEditMemoDialog(UnifiedCatchRecord record) async {
    final memoCtrl = TextEditingController(text: record.memo);
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
        title: const Text("기록 편집",
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1976D2))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(memoCtrl, '메모', '포인트, 미끼 종류, 날씨 등', Icons.edit_note,
                  maxLines: 3),
              const SizedBox(height: 14),
              _textField(lengthCtrl, '길이 (cm)', '예: 45.5', Icons.straighten,
                  isNumber: true, suffix: 'cm'),
              const SizedBox(height: 14),
              _textField(weightCtrl, '무게 (g)', '예: 1200',
                  Icons.monitor_weight_outlined,
                  isNumber: true, suffix: 'g'),
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
                      record,
                      memoCtrl.text.trim(),
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

  Widget _textField(TextEditingController c, String label, String hint,
      IconData icon,
      {bool isNumber = false, String? suffix, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        suffixText: suffix,
      ),
    );
  }

  Future<void> _saveRecordEdits(UnifiedCatchRecord original, String memo,
      double? lengthCm, double? weightG) async {
    await repo.update(original.copyWith(
      memo: memo,
      lengthCm: lengthCm,
      weightG: weightG,
    ));

    bool newPB = false;
    final prefs = await SharedPreferences.getInstance();
    if (lengthCm != null) {
      final prev = prefs.getDouble(_pbLengthKey(original.fishName)) ?? 0.0;
      if (lengthCm > prev) {
        await prefs.setDouble(_pbLengthKey(original.fishName), lengthCm);
        newPB = true;
      }
    }
    if (weightG != null) {
      final prev = prefs.getDouble(_pbWeightKey(original.fishName)) ?? 0.0;
      if (weightG > prev) {
        await prefs.setDouble(_pbWeightKey(original.fishName), weightG);
        newPB = true;
      }
    }

    if (mounted && newPB) _showPBAlert(original.fishName, lengthCm, weightG);
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

  // ━━━ 어종 추가/삭제 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _showAddCustomFishDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text("새 어종 추가",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1976D2))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _textField(nameCtrl, '어종 이름', '예: 농어, 광어', Icons.set_meal),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '어종 추가 후 사진은 카드의 + 버튼으로 추가하세요',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    await repo.addCustomFish(name);
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
      ),
    );
  }

  Future<void> _confirmDeleteFish(BuildContext ctx, String fishName) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
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
            child: const Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final r in recordMap[fishName] ?? <UnifiedCatchRecord>[]) {
        if (r.imagePath != null) {
          try {
            final file = File(r.imagePath!);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      await repo.deleteByFish(fishName);
    }
  }

  // ━━━ 기록 삭제 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _confirmDeleteRecord(
      BuildContext ctx, UnifiedCatchRecord record) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("기록 삭제"),
        content: const Text("이 기록을 삭제할까요?\n삭제하면 복구할 수 없습니다."),
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
            child: const Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (record.imagePath != null) {
        try {
          final file = File(record.imagePath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await repo.delete(record.id);
    }
  }

  // ━━━ 상세 팝업 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String _formatDate(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} "
        "$amPm $hour:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _weightLabel(double g) => g >= 1000
      ? '${(g / 1000).toStringAsFixed(2)} kg'
      : '${g.toStringAsFixed(0)} g';

  void _showFishDetailPopup(
      BuildContext context, UnifiedCatchRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(record.fishName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1976D2))),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: record.hasPhoto
                    ? Image.file(File(record.imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 230,
                        errorBuilder: (_, __, ___) =>
                            _buildNoPhotoLarge(record))
                    : _buildNoPhotoLarge(record),
              ),
              const SizedBox(height: 14),
              _InfoTile(
                  icon: Icons.calendar_month_rounded,
                  label: "포획 일시",
                  value: _formatDate(record.catchTime)),
              const SizedBox(height: 8),
              _InfoTile(
                icon: record.hasLocation
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                label: "포획 위치",
                value: record.displayLocation,
                iconColor: record.hasLocation
                    ? const Color(0xFF1976D2)
                    : Colors.grey,
              ),
              if (record.count > 1) ...[
                const SizedBox(height: 8),
                _InfoTile(
                    icon: Icons.water_drop_outlined,
                    label: "마릿수",
                    value: '${record.count}마리'),
              ],
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
                                "${record.lengthCm!.toStringAsFixed(1)} cm"),
                      ),
                    if (record.lengthCm != null && record.weightG != null)
                      const SizedBox(width: 8),
                    if (record.weightG != null)
                      Expanded(
                        child: _InfoTile(
                            icon: Icons.monitor_weight_outlined,
                            label: "무게",
                            value: _weightLabel(record.weightG!)),
                      ),
                  ],
                ),
              ],
              if (record.memo.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoTile(
                    icon: Icons.sticky_note_2_outlined,
                    label: "메모",
                    value: record.memo),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                      ),
                      icon: const Icon(Icons.edit,
                          color: Color(0xFF1976D2), size: 18),
                      label: const Text("편집",
                          style: TextStyle(color: Color(0xFF1976D2))),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _showEditMemoDialog(record);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (record.hasPhoto) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.green),
                        ),
                        icon: const Icon(Icons.share,
                            color: Colors.green, size: 18),
                        label: const Text("공유",
                            style: TextStyle(color: Colors.green)),
                        onPressed: () => _shareRecord(record),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B3A55),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildNoPhotoLarge(UnifiedCatchRecord record) {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withOpacity(0.08),
            const Color(0xFF42A5F5).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(record.emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 10),
          Text(
            record.spotName ?? "지도에서 기록한 조과",
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text("📷 사진 없음",
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _shareRecord(UnifiedCatchRecord record) async {
    if (!record.hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("사진이 없는 기록은 공유할 수 없어요"),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await ShareCardUtil.shareRecord(
      context,
      fishName: record.fishName,
      record: CatchRecordForShare(
        imagePath: record.imagePath!,
        catchTime: record.catchTime,
        locationName: record.displayLocation == '위치 정보 없음'
            ? null
            : record.displayLocation,
        latitude: record.latitude,
        longitude: record.longitude,
        lengthCm: record.lengthCm,
        weightG: record.weightG,
        memo: record.memo.isEmpty ? null : record.memo,
      ),
    );
  }

  void _openGearShop() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GearShopScreen()));
  }

  // ━━━ UI 빌드 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final collected = allFishNames
        .where((n) => (recordMap[n]?.isNotEmpty ?? false))
        .length;
    final total = allFishNames.length;
    final progress = total > 0 ? collected / total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('낚시 도감',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
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
          label: const Text("어종 추가",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
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
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 120),
        children: [
          _buildCompactProgress(collected, total, progress),
          const SizedBox(height: 12),
          _buildGearShopButton(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("📖 어종 도감",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF212529))),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text("$collected / $total 종",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF868E96),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...allFishNames.map((name) {
            final records = recordMap[name] ?? <UnifiedCatchRecord>[];
            final isCustom = customFishNames.contains(name);
            return _FishCard(
              fishName: name,
              records: records,
              isCustom: isCustom,
              onPhotoAdd: () => _addPhotoToFish(name),
              onRecordTap: (r) => _showFishDetailPopup(context, r),
              onRecordDelete: (r) => _confirmDeleteRecord(context, r),
              onFishDelete: isCustom
                  ? () => _confirmDeleteFish(context, name)
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactProgress(int collected, int total, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text("🐟", style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("$collected",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.0)),
                    Text(" / $total 종",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text("${(progress * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD54F)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGearShopButton() {
    return GestureDetector(
      onTap: _openGearShop,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9ECEF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text("🛠️", style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("장비 추천 보기",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF212529))),
                  SizedBox(height: 2),
                  Text("낚시 입문자를 위한 필수 장비 3종",
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF868E96),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF868E96)),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 장비 추천 페이지
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GearShopScreen extends StatelessWidget {
  const GearShopScreen({super.key});

  Future<void> _launchURL(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('장비 추천',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text("🎣", style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("낚시 입문 필수 장비",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text("처음 시작하는 분들을 위한 기본 세트.\n탭하면 쿠팡에서 검색돼요.",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...kCommonGear.map((gear) => _GearDetailCard(
                name: gear['name'],
                icon: gear['icon'],
                description: gear['description'],
                color: gear['color'],
                onTap: () => _launchURL(gear['url']),
              )),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "본 앱은 장비 판매처와 제휴 관계가 없으며, 쿠팡 검색 결과로 안내해드립니다. "
                    "실제 구매 시에는 가격·리뷰·재고 등을 직접 확인해주세요.",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GearDetailCard extends StatelessWidget {
  final String name;
  final String icon;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _GearDetailCard({
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF212529))),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7684),
                            height: 1.45)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text("쿠팡에서 보기",
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 2),
                        Icon(Icons.open_in_new, size: 11, color: color),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📌 보조 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

class _FishCard extends StatelessWidget {
  final String fishName;
  final List<UnifiedCatchRecord> records;
  final bool isCustom;
  final VoidCallback onPhotoAdd;
  final void Function(UnifiedCatchRecord) onRecordTap;
  final void Function(UnifiedCatchRecord) onRecordDelete;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            child: record.hasPhoto
                                ? Image.file(File(record.imagePath!),
                                    width: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _noPhotoThumb(record))
                                : _noPhotoThumb(record),
                          ),
                          if (record.hasLocation)
                            Positioned(
                              top: 6, right: 6,
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
                          if (record.memo.isNotEmpty)
                            Positioned(
                              bottom: 6, right: 6,
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
                          if (!record.hasPhoto)
                            Positioned(
                              bottom: 6, left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text("📷 사진 없음",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10)),
                              ),
                            ),
                          Positioned(
                            top: 6, left: 6,
                            child: GestureDetector(
                              onTap: () => onRecordDelete(record),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4),
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
                ? "수집 완료 (${records.length}건)"
                : "미수집"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: Color(0xFF1976D2)),
                  tooltip: "사진 + 정보 추가",
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

  Widget _noPhotoThumb(UnifiedCatchRecord r) {
    return Container(
      width: 220, height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withOpacity(0.1),
            const Color(0xFF42A5F5).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(r.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 6),
          Text(
            r.spotName ?? '지도에서 기록',
            style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (r.count > 1) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${r.count}마리',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}