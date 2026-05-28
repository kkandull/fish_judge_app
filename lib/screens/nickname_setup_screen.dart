// lib/screens/nickname_setup_screen.dart
//
// 닉네임 설정 화면.
// ✅ 키보드 올라올 때 OVERFLOW 41px 문제 해결

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);
const Color _kOrange = Color(0xFFF97316);

class NicknameSetupScreen extends StatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validate(String nickname) {
    if (nickname.isEmpty) return '닉네임을 입력해주세요';
    if (nickname.length < 2) return '2자 이상 입력해주세요';
    if (nickname.length > 10) return '10자 이내로 입력해주세요';
    
    // 한글/영문/숫자만 허용
    final regex = RegExp(r'^[가-힣a-zA-Z0-9]+$');
    if (!regex.hasMatch(nickname)) {
      return '특수문자는 사용할 수 없어요';
    }
    
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final nickname = _controller.text.trim();
    
    final error = _validate(nickname);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      HapticFeedback.mediumImpact();
      await AuthService.instance.setNickname(nickname);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text("'$nickname'으로 설정됐어요"),
            ]),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ 키보드 올라올 때 자동으로 화면 조정
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '닉네임 설정',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: _kNavy),
      ),
      // ✅ SingleChildScrollView로 감싸서 키보드와 충돌 안 함
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('👋', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '커뮤니티에 오신 걸 환영해요',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _kPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '회원가입 없이 닉네임만 정하면 시작',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kPrimary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // 닉네임 라벨
            const Text(
              '닉네임',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 10),
            
            // 입력 필드
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              maxLength: 10,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 16, color: _kNavy),
              decoration: InputDecoration(
                hintText: '예: 부산낚시왕',
                hintStyle: const TextStyle(color: _kSub),
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _error != null ? _kRed : Colors.transparent,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _error != null ? _kRed : _kPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            
            // 에러 메시지
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: _kRed, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _error!,
                    style: const TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            
            // 규칙 안내
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ruleRow(Icons.check_circle_outline, '2~10자 (한글, 영문, 숫자)'),
                const SizedBox(height: 8),
                _ruleRow(Icons.check_circle_outline, '특수문자 사용 불가'),
                const SizedBox(height: 8),
                _ruleRow(Icons.warning_amber_rounded, '한 번 정하면 변경할 수 없어요', color: _kOrange),
              ],
            ),
            const SizedBox(height: 32),
            
            // ✅ 시작하기 버튼을 본문에 배치 (bottomNavigationBar 안 씀)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '시작하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            // ✅ 키보드 위 여백 (스크롤 가능)
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(IconData icon, String text, {Color? color}) {
    final c = color ?? _kSub;
    return Row(
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: c,
            fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}