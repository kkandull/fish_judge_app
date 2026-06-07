// lib/screens/settings_screen.dart
// ✅ 설정 화면
// - 앱 버전 정보
// - 개인정보처리방침 링크
// - 오픈소스 라이선스
// - 피드백 보내기 (Firestore 저장)
// - 캐시 초기화

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/feedback_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy   = Color(0xFF212529);
const Color _kSub    = Color(0xFF868E96);
const Color _kBg     = Color(0xFFF5F7FA);
const Color _kBorder = Color(0xFFE8EAED);

// ⭐ 여기에 GitHub Pages URL 입력
const String _kPrivacyPolicyUrl =
    'https://kkandull.github.io/nowfishing/privacy.html';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    // package_info_plus 없이 하드코딩 (pubspec.yaml version과 동기화)
    _appVersion = '1.0.0';
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('페이지를 열 수 없어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('캐시 초기화',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
        content: const Text('저장된 날씨 캐시와 임시 데이터를 삭제합니다.\n조과 기록은 삭제되지 않아요.',
            style: TextStyle(fontSize: 13, color: _kSub, height: 1.5)),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소', style: TextStyle(color: _kSub)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('초기화', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      // 날씨 캐시 키만 삭제 (조과 기록 제외)
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('weather_') || key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캐시가 초기화되었어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFeedbackDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => _FeedbackDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text('설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 앱 정보 ──────────────────────────────────
          _SectionHeader(title: '앱 정보'),
          _SettingCard(children: [
            _InfoTile(
              icon: Icons.water_rounded,
              iconColor: _kPrimary,
              title: '나우피싱',
              subtitle: 'AI 낚시 어종 판독',
            ),
            _Divider(),
            _InfoTile(
              icon: Icons.tag_rounded,
              iconColor: _kSub,
              title: '버전',
              subtitle: _appVersion,
            ),
          ]),

          const SizedBox(height: 16),

          // ── 피드백 ────────────────────────────────────
          _SectionHeader(title: '의견 보내기'),
          _SettingCard(children: [
            _ActionTile(
              icon: Icons.rate_review_outlined,
              iconColor: const Color(0xFF00BFA5),
              title: '피드백 보내기',
              subtitle: '불편한 점이나 개선 의견을 알려주세요',
              onTap: _showFeedbackDialog,
            ),
          ]),

          const SizedBox(height: 16),

          // ── 법적 고지 ─────────────────────────────────
          _SectionHeader(title: '법적 고지'),
          _SettingCard(children: [
            _ActionTile(
              icon: Icons.privacy_tip_outlined,
              iconColor: _kPrimary,
              title: '개인정보처리방침',
              subtitle: '수집하는 정보와 사용 방법 안내',
              onTap: () => _openUrl(_kPrivacyPolicyUrl),
              showArrow: true,
            ),
            _Divider(),
            _ActionTile(
              icon: Icons.article_outlined,
              iconColor: _kSub,
              title: '오픈소스 라이선스',
              subtitle: '사용된 오픈소스 라이브러리 목록',
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: '나우피싱',
                  applicationVersion: _appVersion,
                  applicationLegalese: '© 2025 NowFishing Team',
                );
              },
              showArrow: true,
            ),
          ]),

          const SizedBox(height: 16),

          // ── 데이터 관리 ───────────────────────────────
          _SectionHeader(title: '데이터 관리'),
          _SettingCard(children: [
            _ActionTile(
              icon: Icons.cleaning_services_outlined,
              iconColor: Colors.orange,
              title: '캐시 초기화',
              subtitle: '날씨 캐시 및 임시 데이터 삭제',
              onTap: _clearCache,
            ),
          ]),

          const SizedBox(height: 16),

          // ── 문의 ──────────────────────────────────────
          _SectionHeader(title: '문의'),
          _SettingCard(children: [
            _ActionTile(
              icon: Icons.email_outlined,
              iconColor: _kPrimary,
              title: '이메일 문의',
              subtitle: 'nowfishing.support@gmail.com',
              onTap: () => _openUrl('mailto:nowfishing.support@gmail.com'),
            ),
          ]),

          const SizedBox(height: 32),

          // 하단 앱 버전 표시
          Center(
            child: Text(
              'NowFishing v$_appVersion\n© 2025 NowFishing Team',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _kSub, height: 1.6),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 피드백 다이얼로그
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FeedbackDialog extends StatefulWidget {
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _ctrl = TextEditingController();
  String _selectedType = 'general';
  int _rating = 0;
  bool _submitting = false;

  final _types = [
    {'value': 'general', 'label': '일반 의견', 'icon': Icons.chat_bubble_outline},
    {'value': 'bug',     'label': '버그 신고', 'icon': Icons.bug_report_outlined},
    {'value': 'feature', 'label': '기능 요청', 'icon': Icons.lightbulb_outlined},
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _submitting = true);
    try {
      await FeedbackService.instance.submitFeedback(
        type: _selectedType,
        content: _ctrl.text,
        rating: _rating > 0 ? _rating : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('피드백을 보내주셔서 감사해요! 🙏'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF00BFA5),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전송에 실패했어요. 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

          // 헤더
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.rate_review_outlined, color: Color(0xFF00BFA5), size: 20)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('피드백 보내기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
              Text('더 나은 앱을 만드는 데 도움이 돼요',
                style: TextStyle(fontSize: 11, color: _kSub)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: _kSub, size: 20)),
          ]),
          const SizedBox(height: 20),

          // 유형 선택
          const Text('유형', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSub)),
          const SizedBox(height: 8),
          Row(children: _types.map((t) {
            final selected = _selectedType == t['value'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedType = t['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _kPrimary : _kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? _kPrimary : _kBorder)),
                child: Column(children: [
                  Icon(t['icon'] as IconData,
                    size: 18, color: selected ? Colors.white : _kSub),
                  const SizedBox(height: 4),
                  Text(t['label'] as String,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _kSub)),
                ]),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),

          // 별점
          const Text('만족도', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSub)),
          const SizedBox(height: 8),
          Row(children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 32, color: filled ? const Color(0xFFFFC107) : _kBorder)),
            );
          })),
          const SizedBox(height: 16),

          // 내용 입력
          const Text('내용', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSub)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '불편한 점, 개선 의견, 버그 내용을 자유롭게 적어주세요',
              hintStyle: const TextStyle(fontSize: 13, color: _kSub),
              filled: true, fillColor: _kBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('보내기',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공통 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSub,
          letterSpacing: 0.3)),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: _kBorder);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _kSub)),
        ])),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showArrow;
  const _ActionTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
    this.showArrow = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _kSub)),
          ])),
          if (showArrow) const Icon(Icons.chevron_right, color: _kSub, size: 18),
        ]),
      ),
    );
  }
}