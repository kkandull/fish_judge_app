// lib/screens/nickname_setup_screen.dart
//
// 커뮤니티 첫 진입 시 닉네임을 설정하는 화면.
// 한 번 정하면 변경 불가.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kBg = Color(0xFFF2F4F6);

class NicknameSetupScreen extends StatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _error = null;
      _isValid = trimmed.length >= 2 && trimmed.length <= 10 &&
                 RegExp(r'^[a-zA-Z0-9가-힣]+$').hasMatch(trimmed);
    });
  }

  Future<void> _submit() async {
    if (!_isValid || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      HapticFeedback.mediumImpact();
      await AuthService.instance.setNickname(_controller.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '닉네임 설정',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: _kNavy),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // 안내 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Text('👋', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '커뮤니티에 오신 걸 환영해요',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kNavy),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '회원가입 없이 닉네임만 정하면 시작',
                            style: TextStyle(fontSize: 12, color: _kSub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                '닉네임',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kNavy),
              ),
              const SizedBox(height: 8),

              // 입력 필드
              TextField(
                controller: _controller,
                maxLength: 10,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 16, color: _kNavy),
                decoration: InputDecoration(
                  hintText: '예: 부산낚시왕',
                  hintStyle: const TextStyle(color: _kSub),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kPrimary, width: 2),
                  ),
                  errorText: _error,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),

              // 글자 수 표시
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_controller.text.length} / 10',
                  style: const TextStyle(fontSize: 12, color: _kSub),
                ),
              ),
              const SizedBox(height: 16),

              // 규칙 안내
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RuleRow(text: '2~10자 (한글, 영문, 숫자)'),
                    _RuleRow(text: '특수문자 사용 불가'),
                    _RuleRow(text: '한 번 정하면 변경할 수 없어요', isWarning: true),
                  ],
                ),
              ),

              const Spacer(),

              // 시작하기 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isValid && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          '시작하기',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String text;
  final bool isWarning;
  const _RuleRow({required this.text, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 14,
            color: isWarning ? Colors.orange : _kSub,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isWarning ? Colors.orange.shade800 : _kSub,
              fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
