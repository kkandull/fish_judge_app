// lib/screens/post_compose_screen.dart
//
// 게시글 작성 화면 v3.
// ✅ 사진 최대 5장 다중 업로드 (가로 스크롤, 인스타 스타일)
// ✅ 작성 가이드 표시
// ✅ 금지 키워드 클라이언트 1차 필터링 (정치/성/욕설)
// ✅ 제출 전 최종 확인 다이얼로그

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';
import '../utils/image_encoder.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);
const Color _kOrange = Color(0xFFF97316);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 금지 키워드 (1차 필터 — 명확한 것들만)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const List<String> _kBannedKeywords = [
  '대통령', '국힘', '민주당', '국민의힘', '좌파', '우파', '빨갱이', '토착왜구',
  '윤석열', '이재명', '문재인', '박근혜', '윤어게인', '보수', '진보',
  '예수쟁이', '땡중',
  '시발', '씨발', 'ㅅㅂ', 'ㅄ', '병신', '븅신', '개새끼',
  '섹스', '야동', '몸캠', '조건만남',
];

class PostComposeScreen extends StatefulWidget {
  final String? prefilledFishName;
  final File? prefilledImage;

  const PostComposeScreen({
    super.key,
    this.prefilledFishName,
    this.prefilledImage,
  });

  @override
  State<PostComposeScreen> createState() => _PostComposeScreenState();
}

class _PostComposeScreenState extends State<PostComposeScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _picker = ImagePicker();

  String _category = 'catch';
  final List<File> _selectedImages = [];
  static const int _maxImages = 5;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledFishName != null) {
      _titleController.text = '${widget.prefilledFishName} 잡았어요!';
    }
    if (widget.prefilledImage != null) {
      _selectedImages.add(widget.prefilledImage!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 이미지 선택
  // ─────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    try {
      final remaining = _maxImages - _selectedImages.length;
      if (remaining <= 0) return;

      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked.isEmpty || !mounted) return;

      final toAdd = picked.take(remaining).map((e) => File(e.path)).toList();
      setState(() => _selectedImages.addAll(toAdd));

      if (picked.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최대 $_maxImages장까지만 추가할 수 있어요')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진을 가져올 수 없어요: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      if (_selectedImages.length >= _maxImages) return;

      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImages.add(File(picked.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라를 열 수 없어요: $e')),
        );
      }
    }
  }

  void _showImagePicker() {
    // 이미 최대 장수면 안내
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진은 최대 $_maxImages장까지 추가할 수 있어요')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kPrimary),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kPrimary),
              title: const Text('갤러리에서 선택'),
              subtitle: Text(
                '최대 ${_maxImages - _selectedImages.length}장 더 추가 가능',
                style: const TextStyle(fontSize: 11, color: _kSub),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedImages.removeAt(index));
  }

  // ─────────────────────────────────────────────
  // 금지 키워드 검사
  // ─────────────────────────────────────────────

  String? _checkBannedKeywords(String text) {
    final lower = text.toLowerCase();
    for (final keyword in _kBannedKeywords) {
      if (lower.contains(keyword.toLowerCase())) return keyword;
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // 제출
  // ─────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showError('제목을 입력해주세요');
      return;
    }
    if (body.length < 5) {
      _showError('내용을 5자 이상 입력해주세요');
      return;
    }

    // 금지 키워드 1차 검사
    final banned = _checkBannedKeywords('$title $body');
    if (banned != null) {
      await _showBannedKeywordDialog(banned);
      return;
    }

    // 최종 확인
    final confirmed = await _showFinalConfirmation();
    if (confirmed != true) return;

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      // 이미지 인코딩 (여러 장)
      final List<String> thumbList = [];
      final List<String> fullList = [];

      for (final file in _selectedImages) {
        final encoded = await ImageEncoder.encodeImage(file);
        thumbList.add(encoded['thumbnail']!);
        fullList.add(encoded['full']!);
      }

      await PostService.instance.createPost(
        title: title,
        body: body,
        category: _category,
        linkedFishName: widget.prefilledFishName,
        imageBase64Thumbs: thumbList,
        imageBase64Fulls: fullList,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('게시글이 등록됐어요'),
          ]),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showError('등록 실패: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showBannedKeywordDialog(String keyword) async {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.warning, color: _kRed, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              '게시 불가',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '커뮤니티 규칙에 위배되는 단어가 포함되어 있어요.',
              style: TextStyle(fontSize: 14, color: _kNavy, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: _kRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '감지된 단어: "$keyword"',
                      style: const TextStyle(
                        color: _kRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '나우피싱은 정치·종교·음란성 콘텐츠를 허용하지 않습니다.\n낚시 관련 내용으로 작성해주세요.',
              style: TextStyle(fontSize: 12, color: _kSub, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              '확인',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showFinalConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('등록하시겠어요?'),
        content: const Text(
          '게시 후에는 본인 외에 수정이 어렵습니다.\n내용을 한 번 더 확인해주세요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('다시 보기', style: TextStyle(color: _kSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              elevation: 0,
            ),
            child: const Text(
              '등록하기',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 빌드
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text(
          '글쓰기',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                disabledBackgroundColor: Colors.grey[300],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      '등록',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성 가이드
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '낚시 관련 내용만 작성해주세요. 정치·종교·음란성 글은 금지되며, 발견 시 즉시 제재됩니다.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 카테고리
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, color: _kNavy)),
            const SizedBox(height: 10),
            Row(
              children: [
                _categoryCard('catch', '🎣', '조과 자랑', _kPrimary),
                const SizedBox(width: 8),
                _categoryCard('question', '❓', '질문', _kOrange),
                const SizedBox(width: 8),
                _categoryCard('info', '💡', '정보 공유', const Color(0xFF03C75A)),
              ],
            ),
            const SizedBox(height: 20),

            // 제목
            TextField(
              controller: _titleController,
              maxLength: 50,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                hintStyle: TextStyle(fontSize: 18, color: _kSub),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            const Divider(color: _kBorder),
            const SizedBox(height: 12),

            // 본문
            TextField(
              controller: _bodyController,
              maxLength: 2000,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: _category == 'catch'
                    ? '오늘의 조과를 공유해보세요\n포인트, 미끼, 날씨 등 상세히 적으면 좋아요!'
                    : _category == 'question'
                        ? '낚시에 관해 궁금한 점을 물어보세요\n초보 질문도 환영합니다!'
                        : '도움이 되는 낚시 정보를 공유해보세요',
                hintStyle: const TextStyle(color: _kSub, fontSize: 14, height: 1.6),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),

            // ─── 사진 섹션 ───
            _buildImageSection(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 사진 섹션 위젯
  // ─────────────────────────────────────────────

  Widget _buildImageSection() {
    final hasImages = _selectedImages.isNotEmpty;
    final canAddMore = _selectedImages.length < _maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 16, color: _kNavy),
            const SizedBox(width: 6),
            const Text(
              '사진',
              style: TextStyle(fontWeight: FontWeight.bold, color: _kNavy, fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              '${_selectedImages.length}/$_maxImages',
              style: TextStyle(
                fontSize: 12,
                color: _selectedImages.length >= _maxImages ? _kRed : _kSub,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (hasImages) ...[
          // ── 가로 스크롤 썸네일 목록 ──
          SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: canAddMore
                  ? _selectedImages.length + 1  // 마지막에 추가 버튼
                  : _selectedImages.length,
              itemBuilder: (context, index) {
                // 추가 버튼 칸
                if (index == _selectedImages.length) {
                  return _buildAddMoreButton();
                }
                // 사진 썸네일
                return _buildImageThumb(index);
              },
            ),
          ),
        ] else ...[
          // ── 사진 없을 때 큰 버튼 ──
          GestureDetector(
            onTap: _showImagePicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _kPrimary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_a_photo, color: _kPrimary, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '📷 사진 첨부하기',
                    style: TextStyle(
                      color: _kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '최대 5장 • 갤러리 또는 카메라',
                    style: TextStyle(color: _kSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 사진 썸네일 아이템
  Widget _buildImageThumb(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // 이미지
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImages[index],
              width: 100,
              height: 104,
              fit: BoxFit.cover,
            ),
          ),

          // 대표 뱃지 (첫 번째 사진)
          if (index == 0)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '대표',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 삭제 버튼
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 사진 추가 버튼 (스크롤 목록 마지막)
  Widget _buildAddMoreButton() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        width: 100,
        height: 104,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _kPrimary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: _kPrimary, size: 26),
            const SizedBox(height: 6),
            Text(
              '${_maxImages - _selectedImages.length}장 추가',
              style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 카테고리 카드
  // ─────────────────────────────────────────────

  Widget _categoryCard(String code, String emoji, String label, Color color) {
    final isSelected = _category == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _category = code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : _kBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : _kSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}