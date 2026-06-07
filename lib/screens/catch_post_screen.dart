// lib/screens/catch_post_screen.dart
//
// 조과 기록 → 낚시 블로그/카페 글 자동 변환
// ─ 3가지 템플릿 (블로그 / 카페 / 인스타)
// ─ 메모, 크기, 무게, 위치 자동 포함
// ─ 전체 복사 / 커뮤니티 공유

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/unified_catch_record.dart';
import 'post_compose_screen.dart';

const Color _kBlue  = Color(0xFF1976D2);
const Color _kNavy  = Color(0xFF1A1A2E);
const Color _kSub   = Color(0xFF6B7684);
const Color _kGreen = Color(0xFF03C75A);
const Color _kOrange= Color(0xFFF97316);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 데이터 구조
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PostData {
  final String fish;
  final String date;
  final String time;
  final String spot;
  final String? addr;
  final String size;
  final String count;
  final String? memo;

  _PostData.from(UnifiedCatchRecord r)
      : fish   = r.fishName,
        date   = '${r.catchTime.year}년 ${r.catchTime.month}월 ${r.catchTime.day}일',
        time   = _fmtTime(r.catchTime),
        spot   = r.spotName ?? (r.displayLocation != '위치 정보 없음' ? r.displayLocation : '낚시 포인트'),
        addr   = r.displayLocation != '위치 정보 없음' ? r.displayLocation : null,
        size   = [
                   if (r.lengthCm != null) '${r.lengthCm!.toStringAsFixed(1)}cm',
                   if (r.weightG != null)
                     r.weightG! >= 1000
                         ? '${(r.weightG!/1000).toStringAsFixed(2)}kg'
                         : '${r.weightG!.toStringAsFixed(0)}g',
                 ].join(' / '),
        count  = r.count > 1 ? '${r.count}마리' : '1마리',
        memo   = r.memo.isNotEmpty ? r.memo : null;

  static String _fmtTime(DateTime dt) {
    final ap = dt.hour < 12 ? '오전' : '오후';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$ap $h:${dt.minute.toString().padLeft(2,'0')}';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 메인 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CatchPostScreen extends StatefulWidget {
  final UnifiedCatchRecord record;
  const CatchPostScreen({super.key, required this.record});

  @override
  State<CatchPostScreen> createState() => _CatchPostScreenState();
}

class _CatchPostScreenState extends State<CatchPostScreen> {
  int _tplIdx = 0;
  bool _copied = false;
  late final _PostData _d;

  // 사용자 편집 가능 컨트롤러
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _d = _PostData.from(widget.record);
    _titleCtrl = TextEditingController();
    _bodyCtrl  = TextEditingController();
    _resetControllers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _resetControllers() {
    _titleCtrl.text = _buildTitle(_tplIdx, _d);
    _bodyCtrl.text  = _buildBody(_tplIdx, _d);
  }

  // ── 전체 텍스트 ─────────────────────────────────────
  String get _fullText {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (_tplIdx == 2) return body; // 인스타는 제목 없음
    return '$title\n\n$body';
  }

  // ── 템플릿 제목 ─────────────────────────────────────
  String _buildTitle(int idx, _PostData d) {
    switch (idx) {
      case 0: return '[${d.fish} 조과] ${d.date} ${d.spot}';
      case 1: return '[${d.fish}] ${d.date} ${d.spot} 조과 공유합니다';
      default: return ''; // 인스타 없음
    }
  }

  // ── 템플릿 본문 ─────────────────────────────────────
  String _buildBody(int idx, _PostData d) {
    switch (idx) {
      case 0: return _blog(d);
      case 1: return _cafe(d);
      default: return _insta(d);
    }
  }

  String _blog(_PostData d) {
    final sb = StringBuffer();
    sb.writeln('안녕하세요 :)');
    sb.writeln('${d.date} ${d.time}에 ${d.spot}에 다녀왔습니다.');
    sb.writeln();
    sb.writeln('【 조과 정보 】');
    sb.writeln('• 어종: ${d.fish}');
    sb.writeln('• 날짜: ${d.date}');
    if (d.addr != null) sb.writeln('• 포인트: ${d.addr}');
    if (d.size.isNotEmpty) sb.writeln('• 크기: ${d.size}');
    sb.writeln('• 마릿수: ${d.count}');
    if (d.memo != null) {
      sb.writeln();
      sb.writeln('【 조황 및 메모 】');
      sb.writeln(d.memo!);
    }
    sb.writeln();
    sb.writeln('오늘도 즐거운 낚시였습니다!');
    sb.writeln('좋아요와 댓글은 큰 힘이 됩니다 🎣');
    return sb.toString().trim();
  }

  String _cafe(_PostData d) {
    final sb = StringBuffer();
    sb.writeln('어종: ${d.fish}');
    sb.writeln('날짜: ${d.date}');
    sb.writeln('포인트: ${d.spot}');
    if (d.addr != null && d.addr != d.spot) sb.writeln('주소: ${d.addr}');
    if (d.size.isNotEmpty) sb.writeln('크기: ${d.size}');
    sb.writeln('마릿수: ${d.count}');
    if (d.memo != null) {
      sb.writeln();
      sb.writeln('─ 메모 ─');
      sb.writeln(d.memo!);
      sb.writeln();
    } else {
      sb.writeln();
    }
    sb.writeln('#낚시 #${d.fish}낚시 #${d.spot.replaceAll(' ','')} #조과 #낚시인');
    return sb.toString().trim();
  }

  String _insta(_PostData d) {
    final sb = StringBuffer();
    sb.writeln('오늘의 조과 🐟');
    sb.writeln();
    sb.writeln('${d.date}  ${d.spot}');
    sb.writeln('${d.fish}  ${d.count}${d.size.isNotEmpty ? "  (${d.size})" : ""}');
    if (d.memo != null) {
      sb.writeln();
      sb.writeln(d.memo!);
    }
    sb.writeln();
    sb.writeln('#낚시 #낚시스타그램 #${d.fish}낚시 #바다낚시');
    sb.writeln('#조과공유 #${d.spot.replaceAll(' ', '')} #낚시인');
    return sb.toString().trim();
  }

  // ── 복사 ────────────────────────────────────────────
  void _copy() {
    Clipboard.setData(ClipboardData(text: _fullText));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('클립보드에 복사됐어요'),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── 커뮤니티 ────────────────────────────────────────
  Future<void> _shareToApp() async {
    if (!widget.record.hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진이 있는 기록만 커뮤니티에 공유할 수 있어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // ✅ 파일 존재 확인
    final imageFile = File(widget.record.imagePath!);
    final exists = await imageFile.exists();
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 파일을 찾을 수 없어요. 직접 선택해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostComposeScreen(
          prefilledFishName: widget.record.fishName,
        ),
      ));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostComposeScreen(
        prefilledFishName: widget.record.fishName,
        prefilledImage: imageFile,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text('조과 글 만들기',
            style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _editing = !_editing;
                if (!_editing) _resetControllers(); // 편집 취소 시 초기화
              });
            },
            child: Text(
              _editing ? '초기화' : '편집',
              style: TextStyle(color: _editing ? _kOrange : _kBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 조과 요약 카드
              _buildSummaryCard(),
              const SizedBox(height: 16),

              // 템플릿 선택
              const Text('템플릿',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
              const SizedBox(height: 10),
              Row(children: [
                _tplBtn(0, Icons.article_outlined,  '블로그'),
                const SizedBox(width: 8),
                _tplBtn(1, Icons.forum_outlined,    '카페'),
                const SizedBox(width: 8),
                _tplBtn(2, Icons.camera_alt_outlined,'인스타'),
              ]),
              const SizedBox(height: 16),

              // 생성된 글 (편집 가능)
              Row(
                children: [
                  const Text('생성된 글',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
                  const Spacer(),
                  if (_editing)
                    Text('직접 수정 가능', style: TextStyle(fontSize: 11, color: _kOrange)),
                ],
              ),
              const SizedBox(height: 8),

              // 제목 (인스타 제외)
              if (_tplIdx != 2) ...[
                _textField(_titleCtrl, '제목', maxLines: 1),
                const SizedBox(height: 8),
              ],

              // 본문
              _textField(_bodyCtrl, '본문', maxLines: null),

              const SizedBox(height: 80),
            ]),
          ),
        ),

        // 하단 버튼
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareToApp,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('커뮤니티'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kOrange,
                  side: const BorderSide(color: _kOrange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                label: Text(_copied ? '복사 완료!' : '전체 복사'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _copied ? _kGreen : _kBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tplBtn(int idx, IconData icon, String label) {
    final sel = idx == _tplIdx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _tplIdx = idx;
            _resetControllers();
            _editing = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? _kBlue.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _kBlue : const Color(0xFFE8EAED),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? _kBlue : _kSub, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: sel ? _kBlue : _kSub,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {int? maxLines}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _editing ? _kBlue.withOpacity(0.4) : const Color(0xFFE8EAED),
          width: _editing ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: ctrl,
        enabled: _editing,
        maxLines: maxLines,
        minLines: maxLines == 1 ? 1 : 6,
        style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.65),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kSub),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final r = widget.record;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: r.hasPhoto
              ? Image.file(File(r.imagePath!), width: 56, height: 56, fit: BoxFit.cover)
              : Container(
                  width: 56, height: 56,
                  color: _kBlue.withOpacity(0.1),
                  alignment: Alignment.center,
                  child: Text(r.emoji, style: const TextStyle(fontSize: 28)),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.fishName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kNavy)),
            const SizedBox(height: 3),
            Text(
              [
                _d.date,
                if (_d.addr != null) _d.addr!,
                if (_d.size.isNotEmpty) _d.size,
                _d.count,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 11, color: _kSub),
            ),
            if (_d.memo != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.sticky_note_2_outlined, size: 11, color: _kSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _d.memo!.length > 40 ? '${_d.memo!.substring(0, 40)}...' : _d.memo!,
                    style: const TextStyle(fontSize: 11, color: _kSub),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}