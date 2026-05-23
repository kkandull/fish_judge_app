// lib/screens/post_compose_screen.dart
//
// 게시글 작성 화면.
//
// 도감/AI 판독에서 진입 시 prefilled로 어종/사진 자동 채움.
// 사용 예:
//   PostComposeScreen(
//     prefilledFishName: '감성돔',
//     prefilledImage: File('/path/to/photo.jpg'),
//   )

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);

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
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  
  File? _selectedImage;
  String? _linkedFishName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.prefilledImage;
    _linkedFishName = widget.prefilledFishName;
    
    // 어종이 미리 채워졌으면 제목 힌트 자동 입력
    if (_linkedFishName != null) {
      _titleController.text = '$_linkedFishName 잡았어요!';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진을 가져올 수 없어요: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  void _showImageSourceSheet() {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kPrimary),
              title: const Text('갤러리에서 선택'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kPrimary),
              title: const Text('사진 찍기'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: _kRed),
                title: const Text('사진 제거', style: TextStyle(color: _kRed)),
                onTap: () { Navigator.pop(ctx); setState(() => _selectedImage = null); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    
    FocusScope.of(context).unfocus();
    
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    
    if (title.isEmpty) {
      _showSnack('제목을 입력해주세요', isError: true);
      _titleFocus.requestFocus();
      return;
    }
    if (body.isEmpty) {
      _showSnack('내용을 입력해주세요', isError: true);
      _bodyFocus.requestFocus();
      return;
    }
    
    setState(() => _submitting = true);
    
    try {
      HapticFeedback.mediumImpact();
      await PostService.instance.createPost(
        title: title,
        body: body,
        image: _selectedImage,
        linkedFishName: _linkedFishName,
      );
      
      if (mounted) {
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
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kRed : _kNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_titleController.text.isEmpty && _bodyController.text.isEmpty &&
        _selectedImage == null) {
      return true;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('작성을 취소할까요?'),
        content: const Text('작성 중인 내용이 사라져요'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 쓰기')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '글쓰기',
            style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          iconTheme: const IconThemeData(color: _kNavy),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('등록',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 어종 태그 (있을 때만)
              if (_linkedFishName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('#$_linkedFishName',
                          style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _linkedFishName = null),
                        child: const Icon(Icons.close, size: 14, color: _kPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 제목
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bodyFocus.requestFocus(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                  hintStyle: TextStyle(color: _kSub, fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
              const Divider(color: _kBorder, height: 1),
              const SizedBox(height: 12),
              
              // 본문
              TextField(
                controller: _bodyController,
                focusNode: _bodyFocus,
                maxLength: 2000,
                maxLines: null,
                minLines: 8,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15, color: _kNavy, height: 1.5),
                decoration: const InputDecoration(
                  hintText: '오늘의 조과를 공유해보세요\n또는 어종 질문도 환영해요!',
                  hintStyle: TextStyle(color: _kSub, height: 1.5),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              
              // 선택된 이미지 미리보기
              if (_selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 80),  // 하단 툴바 여백
            ],
          ),
        ),
        // 하단 툴바
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: _kPrimary),
                  onPressed: _showImageSourceSheet,
                  tooltip: '사진 추가',
                ),
                Text(
                  _selectedImage == null ? '사진 추가' : '사진 1장 첨부됨',
                  style: TextStyle(
                    fontSize: 13,
                    color: _selectedImage == null ? _kSub : _kPrimary,
                    fontWeight: _selectedImage != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_bodyController.text.length} / 2000',
                  style: const TextStyle(fontSize: 11, color: _kSub),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
