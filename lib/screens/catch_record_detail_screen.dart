// 조과 일지 상세 화면 — 전체 편집 가능 버전
// 편집 가능: 어종명, 날짜/시간, 포인트명, 길이, 무게, 마릿수, 메모, (사진 추후)
// 읽기 전용: GPS 좌표 (지도 연동)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/unified_catch_record.dart';
import '../services/share_service.dart';
import '../services/catch_record_repository.dart';
import 'post_compose_screen.dart';

const Color _kBlue   = Color(0xFF1976D2);
const Color _kNavy   = Color(0xFF1A1A2E);
const Color _kSub    = Color(0xFF6B7684);
const Color _kBg     = Color(0xFFF5F7FA);
const Color _kGreen  = Color(0xFF03C75A);
const Color _kOrange = Color(0xFFF97316);
const Color _kRed    = Color(0xFFE53935);
const Color _kBorder = Color(0xFFE8EAED);

class CatchRecordDetailScreen extends StatefulWidget {
  final UnifiedCatchRecord record;
  const CatchRecordDetailScreen({super.key, required this.record});

  @override
  State<CatchRecordDetailScreen> createState() => _CatchRecordDetailScreenState();
}

class _CatchRecordDetailScreenState extends State<CatchRecordDetailScreen> {
  late UnifiedCatchRecord _record;
  int _tplIdx = 0;
  bool _copied = false;
  bool _editing = false;
  bool _saving = false;

  // 편집 컨트롤러 
  late TextEditingController _fishNameCtrl;
  late TextEditingController _spotNameCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _countCtrl;
  late TextEditingController _memoCtrl;

  // 날짜/시간 (별도 상태)
  late DateTime _editDate;

  // 사진 교체용
  File? _newPhoto;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _initControllers();
  }

  void _initControllers() {
    _fishNameCtrl = TextEditingController(text: _record.fishName);
    _spotNameCtrl = TextEditingController(text: _record.spotName ?? '');
    _lengthCtrl   = TextEditingController(text: _record.lengthCm?.toStringAsFixed(1) ?? '');
    _weightCtrl   = TextEditingController(text: _record.weightG?.toStringAsFixed(0) ?? '');
    _countCtrl    = TextEditingController(text: '${_record.count}');
    _memoCtrl     = TextEditingController(text: _record.memo);
    _editDate     = _record.catchTime;
    _newPhoto     = null;
  }

  @override
  void dispose() {
    _fishNameCtrl.dispose();
    _spotNameCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    _countCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // 날짜 선택 
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _editDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _kBlue)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_editDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _kBlue)),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _editDate = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? _editDate.hour,
        time?.minute ?? _editDate.minute,
      );
    });
  }

  // 사진 교체 
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: _kBlue),
            title: const Text('카메라로 촬영'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: _kBlue),
            title: const Text('갤러리에서 선택'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          if (_record.hasPhoto || _newPhoto != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _kRed),
              title: const Text('사진 제거', style: TextStyle(color: _kRed)),
              onTap: () => Navigator.pop(ctx, null),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (!mounted) return;

    if (source == null && (_record.hasPhoto || _newPhoto != null)) {
      // 사진 제거 선택
      setState(() => _newPhoto = File('__remove__'));
      return;
    }
    if (source == null) return;

    try {
      final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (picked != null && mounted) setState(() => _newPhoto = File(picked.path));
    } catch (_) {}
  }

  // 저장 
  Future<void> _saveEdit() async {
    final fishName = _fishNameCtrl.text.trim();
    if (fishName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('어종명을 입력해주세요'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      // 사진 처리
      String? newImagePath = _record.imagePath;
      if (_newPhoto != null) {
        if (_newPhoto!.path == '__remove__') {
          // 사진 삭제
          if (_record.imagePath != null) {
            try { final f = File(_record.imagePath!); if (await f.exists()) await f.delete(); } catch (_) {}
          }
          newImagePath = null;
        } else {
          newImagePath = _newPhoto!.path;
        }
      }

      final updated = _record.copyWith(
        fishName: fishName,
        catchTime: _editDate,
        spotName: _spotNameCtrl.text.trim().isEmpty ? null : _spotNameCtrl.text.trim(),
        lengthCm: double.tryParse(_lengthCtrl.text),
        weightG:  double.tryParse(_weightCtrl.text),
        count:    int.tryParse(_countCtrl.text) ?? _record.count,
        memo:     _memoCtrl.text.trim(),
        imagePath: newImagePath,
      );

      await CatchRecordRepository.instance.update(updated);

      if (!mounted) return;
      setState(() {
        _record = updated;
        _editing = false;
        _saving = false;
        _newPhoto = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('수정됐어요'),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() { _editing = false; _newPhoto = null; });
    _initControllers();
  }

  // 삭제 
  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('기록 삭제'),
        content: const Text('이 조과 기록을 삭제할까요?\n삭제하면 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (_record.imagePath != null) {
      try { final f = File(_record.imagePath!); if (await f.exists()) await f.delete(); } catch (_) {}
    }
    await CatchRecordRepository.instance.delete(_record.id);
    if (mounted) Navigator.pop(context, true);
  }

  // 공유 
  Future<void> _copy() async {
    await ShareService.copy(_generated);
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('복사됐어요'),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share() async {
    await ShareService.shareRecordAsCard(
      context,
      record: _record,
      fallbackText: _generated,
    );
  }

  void _shareToApp() {
    if (!_record.hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진이 있는 기록만 커뮤니티에 공유할 수 있어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostComposeScreen(
        prefilledFishName: _record.fishName,
        prefilledImage: File(_record.imagePath!),
      ),
    ));
  }

  // 글 생성 
  String get _generated => switch (_tplIdx) { 0 => _blog(), 1 => _cafe(), _ => _insta() };

  String get _sizeStr {
    final p = <String>[];
    if (_record.lengthCm != null) p.add('${_record.lengthCm!.toStringAsFixed(1)}cm');
    if (_record.weightG != null) p.add(_record.weightG! >= 1000
        ? '${(_record.weightG!/1000).toStringAsFixed(2)}kg'
        : '${_record.weightG!.toStringAsFixed(0)}g');
    return p.join(' / ');
  }

  String get _spotStr => _record.spotName ?? (_record.displayLocation != '위치 정보 없음' ? _record.displayLocation : '낚시 포인트');

  String _blog() {
    final sb = StringBuffer();
    sb.writeln('[${_record.fishName} 조과] ${_record.dateStr} $_spotStr');
    sb.writeln();
    sb.writeln('안녕하세요 :)');
    sb.writeln('${_record.dateStr}에 $_spotStr에 다녀왔습니다.');
    sb.writeln();
    sb.writeln('【 조과 정보 】');
    sb.writeln('• 어종: ${_record.fishName}');
    sb.writeln('• 날짜: ${_record.dateStr}');
    if (_record.displayLocation != '위치 정보 없음') sb.writeln('• 포인트: ${_record.displayLocation}');
    if (_sizeStr.isNotEmpty) sb.writeln('• 크기: $_sizeStr');
    sb.writeln('• 마릿수: ${_record.count}마리');
    if (_record.weather.isNotEmpty && _record.weather != '정보 없음') sb.writeln('• 날씨: ${_record.weather}');
    if (_record.memo.isNotEmpty) { sb.writeln(); sb.writeln('【 메모 】'); sb.writeln(_record.memo); }
    sb.writeln();
    sb.writeln('오늘도 즐거운 낚시였습니다! 🎣');
    return sb.toString().trim();
  }

  String _cafe() {
    final tag = _spotStr.replaceAll(' ', '');
    final sb = StringBuffer();
    sb.writeln('[${_record.fishName}] ${_record.dateStr} $_spotStr 조과 공유합니다');
    sb.writeln();
    sb.writeln('어종: ${_record.fishName}');
    sb.writeln('날짜: ${_record.dateStr}');
    sb.writeln('포인트: $_spotStr');
    if (_sizeStr.isNotEmpty) sb.writeln('크기: $_sizeStr');
    sb.writeln('마릿수: ${_record.count}마리');
    if (_record.memo.isNotEmpty) { sb.writeln(); sb.writeln('─ 메모 ─'); sb.writeln(_record.memo); }
    sb.writeln();
    sb.writeln('#낚시 #${_record.fishName}낚시 #$tag #조과 #낚시인');
    return sb.toString().trim();
  }

  String _insta() {
    final tag = _spotStr.replaceAll(' ', '');
    final sb = StringBuffer();
    sb.writeln('오늘의 조과 🐟');
    sb.writeln();
    sb.writeln('${_record.dateStr}  $_spotStr');
    sb.writeln('${_record.fishName}  ${_record.count}마리${_sizeStr.isNotEmpty ? "  ($_sizeStr)" : ""}');
    if (_record.memo.isNotEmpty) { sb.writeln(); sb.writeln(_record.memo); }
    sb.writeln();
    sb.writeln('#낚시 #낚시스타그램 #${_record.fishName}낚시 #바다낚시 #조과공유 #$tag');
    return sb.toString().trim();
  }

  // 빌드
  @override
  Widget build(BuildContext context) {
    final r = _record;

    // 사진: 새 사진 > 기존 사진
    final displayPhoto = _newPhoto != null && _newPhoto!.path != '__remove__'
        ? _newPhoto
        : (_newPhoto?.path == '__remove__' ? null : (r.hasPhoto ? File(r.imagePath!) : null));

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // SliverAppBar
          SliverAppBar(
            expandedHeight: displayPhoto != null ? 280 : 160,
            pinned: true,
            backgroundColor: _kBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            title: _editing
                ? TextField(
                    controller: _fishNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '어종명 입력',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  )
                : Text(r.fishName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: _editing
                ? [
                    TextButton(onPressed: _cancelEdit, child: const Text('취소', style: TextStyle(color: Colors.white70))),
                    _saving
                        ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : TextButton(onPressed: _saveEdit,
                            child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                  ]
                : [
                    IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), tooltip: '편집', onPressed: () => setState(() => _editing = true)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), tooltip: '삭제', onPressed: _delete),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                // 사진 or 이모지 배경
                displayPhoto != null
                    ? Image.file(displayPhoto, fit: BoxFit.cover, errorBuilder: (_,__,___) => _emojiHero(r))
                    : _emojiHero(r),
                // 편집 중: 사진 교체 버튼
                if (_editing)
                  Positioned(
                    bottom: 16, right: 16,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_a_photo, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('사진 교체', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 편집 안내
              if (_editing)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBlue.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.edit, size: 15, color: _kBlue), SizedBox(width: 8),
                    Expanded( // 👈 Expanded 추가
                      child: Text('모든 항목을 수정할 수 있어요. 수정 후 저장을 눌러주세요.',
                          style: TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),

              // 조과 정보 카드 
              _sectionCard(
                title: '조과 정보', icon: Icons.set_meal,
                child: _editing ? _buildEditForm() : _buildInfoView(r),
              ),

              // 메모 카드 
              _sectionCard(
                title: '메모', icon: Icons.sticky_note_2_outlined,
                trailing: !_editing ? GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_outlined, size: 12, color: _kBlue), SizedBox(width: 4),
                      Text('편집', style: TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ) : null,
                child: _editing
                    ? TextField(
                        controller: _memoCtrl,
                        maxLines: 5, minLines: 3,
                        style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.6),
                        decoration: _inputDeco('포인트, 미끼, 날씨, 조황 등...'),
                      )
                    : r.memo.isNotEmpty
                        ? Container(
                            width: double.infinity, padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
                            child: Text(r.memo, style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.65)),
                          )
                        : GestureDetector(
                            onTap: () => setState(() => _editing = true),
                            child: Container(
                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
                              alignment: Alignment.center,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_comment_outlined, color: _kSub, size: 22),
                                const SizedBox(height: 6),
                                Text('메모 추가하기', style: TextStyle(fontSize: 12, color: _kSub)),
                              ]),
                            ),
                          ),
              ),

              // 저장/취소 버튼 (편집 중)
              if (_editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder), padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소', style: TextStyle(color: _kSub)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: ElevatedButton(
                      onPressed: _saving ? null : _saveEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),

              // 자동 생성 글 (편집 중 숨김) 
              if (!_editing) _buildGeneratedSection(),

              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),

      // 하단 버튼
      bottomNavigationBar: _editing ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _shareToApp,
              icon: const Icon(Icons.forum_outlined, size: 17),
              label: const Text('커뮤니티'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange, side: const BorderSide(color: _kOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined, size: 17),
              label: const Text('공유'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue, side: const BorderSide(color: _kBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 17),
              label: Text(_copied ? '복사 완료!' : '전체 복사'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied ? _kGreen : _kBlue, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  // 보기 모드
  Widget _buildInfoView(UnifiedCatchRecord r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoRow(Icons.category_outlined, '어종', r.fishName),
      _infoRow(Icons.calendar_today_outlined, '날짜', r.dateStr),
      if (r.displayLocation != '위치 정보 없음')
        _infoRow(Icons.location_on_outlined, '포인트', r.displayLocation),
      if (r.weather.isNotEmpty && r.weather != '정보 없음')
        _infoRow(Icons.wb_cloudy_outlined, '날씨', r.weather),
      if (r.lengthCm != null || r.weightG != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          if (r.lengthCm != null) Expanded(child: _statBox(Icons.straighten, '길이', '${r.lengthCm!.toStringAsFixed(1)} cm', _kBlue)),
          if (r.lengthCm != null && r.weightG != null) const SizedBox(width: 8),
          if (r.weightG != null) Expanded(child: _statBox(Icons.monitor_weight_outlined, '무게',
              r.weightG! >= 1000 ? '${(r.weightG!/1000).toStringAsFixed(2)} kg' : '${r.weightG!.toStringAsFixed(0)} g', _kOrange)),
        ]),
      ],
      if (r.count > 1) ...[const SizedBox(height: 8), _infoRow(Icons.numbers_outlined, '마릿수', '${r.count}마리')],
    ]);
  }

  // 편집 폼 (전체 필드) 
  Widget _buildEditForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 어종명
      _fieldLabel('어종명'),
      TextField(
        controller: _fishNameCtrl,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy),
        decoration: _inputDeco('예: 감성돔, 노래미, 우럭'),
      ),
      const SizedBox(height: 14),

      // 포인트명
      _fieldLabel('포인트 이름'),
      TextField(
        controller: _spotNameCtrl,
        style: const TextStyle(fontSize: 14, color: _kNavy),
        decoration: _inputDeco('예: 해운대 방파제 끝단'),
      ),
      const SizedBox(height: 14),

      // 날짜/시간
      _fieldLabel('날짜 / 시간'),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _kBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBlue.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: _kBlue),
            const SizedBox(width: 10),
            Text(
              '${_editDate.year}.${_editDate.month.toString().padLeft(2,'0')}.${_editDate.day.toString().padLeft(2,'0')}'
              '  ${_editDate.hour < 12 ? "오전" : "오후"} ${(_editDate.hour > 12 ? _editDate.hour-12 : _editDate.hour).toString().padLeft(2,'0')}:${_editDate.minute.toString().padLeft(2,'0')}',
              style: const TextStyle(fontSize: 14, color: _kNavy, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar_outlined, size: 16, color: _kSub),
          ]),
        ),
      ),
      const SizedBox(height: 14),

      // 크기 / 무게 / 마릿수
      _fieldLabel('크기 / 무게 / 마릿수'),
      Row(children: [
        Expanded(child: _numField(_lengthCtrl, '길이', 'cm')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_weightCtrl, '무게', 'g')),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: _numField(_countCtrl, '마릿수', '마리')),
      ]),
    ]);
  }

  // 자동 생성 글 섹션 
  Widget _buildGeneratedSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            const Icon(Icons.article_outlined, color: _kBlue, size: 18),
            const SizedBox(width: 8),
            const Text('자동 생성 글', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy)),
            const Spacer(),
            ...List.generate(3, (i) {
              final labels = ['블로그', '카페', '인스타'];
              final sel = i == _tplIdx;
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: GestureDetector(
                  onTap: () => setState(() => _tplIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? _kBlue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _kBlue : Colors.grey[300]!),
                    ),
                    child: Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : _kSub)),
                  ),
                ),
              );
            }),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_generated, style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.7)),
        ),
      ]),
    );
  }

  // 공통 위젯 

  Widget _emojiHero(UnifiedCatchRecord r) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: [_kBlue.withOpacity(0.12), _kBlue.withOpacity(0.04)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    )),
    alignment: Alignment.center,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(r.emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
        child: const Text('사진 없음', style: TextStyle(fontSize: 12, color: _kSub)),
      ),
    ]),
  );

  Widget _sectionCard({required String title, required IconData icon, required Widget child, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _kBlue, size: 16), const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kSub)),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: _kSub), const SizedBox(width: 8),
      Text('$label  ', style: const TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w600)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _statBox(IconData icon, String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color), const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
    ]),
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w600)),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _kSub, fontSize: 13),
    filled: true, fillColor: _kBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBlue.withOpacity(0.4))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBlue.withOpacity(0.3))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Widget _numField(TextEditingController ctrl, String label, String suffix) => TextField(
    controller: ctrl,
    keyboardType: TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kNavy),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11, color: _kSub),
      suffixText: suffix,
      suffixStyle: const TextStyle(fontSize: 11, color: _kSub),
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBlue.withOpacity(0.4))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBlue.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    ),
  );
}