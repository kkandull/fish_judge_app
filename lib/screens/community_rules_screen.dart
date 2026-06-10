// 커뮤니티 운영 정책 화면.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF5F7FA);
const Color _kSub = Color(0xFF6B7684);
const Color _kRed = Color(0xFFFF4B4B);

class CommunityRulesScreen extends StatefulWidget {
  /// true: 처음 진입 (동의 버튼 표시)
  /// false: 그냥 정책 보기
  final bool requiresAgreement;
  
  const CommunityRulesScreen({super.key, this.requiresAgreement = false});

  /// 사용자가 이미 정책에 동의했는지 체크
  static Future<bool> hasAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('community_rules_agreed_v1') ?? false;
  }

  /// 정책 동의 저장
  static Future<void> _setAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('community_rules_agreed_v1', true);
  }

  /// 동의 필요 시 표시 (이미 동의했으면 true 즉시 반환)
  static Future<bool> requireAgreement(BuildContext context) async {
    if (await hasAgreed()) return true;
    
    if (!context.mounted) return false;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CommunityRulesScreen(requiresAgreement: true),
        fullscreenDialog: true,
      ),
    );
    return result == true;
  }

  @override
  State<CommunityRulesScreen> createState() => _CommunityRulesScreenState();
}

class _CommunityRulesScreenState extends State<CommunityRulesScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text(
          '커뮤니티 이용 규칙',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        automaticallyImplyLeading: !widget.requiresAgreement,
        actions: [
          if (widget.requiresAgreement)
            IconButton(
              icon: const Icon(Icons.close, color: _kSub),
              onPressed: () => Navigator.pop(context, false),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Text('🎣', style: TextStyle(fontSize: 36)),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '건강한 낚시 커뮤니티를 위해',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '서로를 존중하며,\n낚시 정보 공유에 집중해요',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 권장 카테고리
                    _section(
                      title: '✅ 이런 글을 환영해요',
                      color: const Color(0xFF03C75A),
                      items: const [
                        _RuleItem('🎣', '조과 자랑', '오늘 잡은 어종, 포인트 후기'),
                        _RuleItem('❓', '낚시 질문', '초보 질문, 어종 식별, 장비 추천'),
                        _RuleItem('💡', '정보 공유', '포인트 정보, 미끼, 시즌 정보'),
                        _RuleItem('🌊', '안전 정보', '날씨 경보, 위험 지역 안내'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 금지 사항 ⭐ 핵심
                    _section(
                      title: '🚫 이런 글은 절대 안 돼요',
                      color: _kRed,
                      items: const [
                        _RuleItem(
                          '🔞',
                          '음란성 / 성희롱',
                          '음란한 사진·내용, 성적 발언, 성희롱은 즉시 차단됩니다',
                        ),
                        _RuleItem(
                          '⚖️',
                          '정치 / 종교 분쟁',
                          '정치 선동, 종교 갈등 조장은 금지입니다',
                        ),
                        _RuleItem(
                          '🤬',
                          '욕설 / 비방 / 혐오',
                          '욕설, 인신공격, 지역·성별·나이 차별 발언 금지',
                        ),
                        _RuleItem(
                          '⚠️',
                          '불법 어업 행위',
                          '금어기 위반, 금지체장 미달, 불법 장비 조과 게시 금지',
                        ),
                        _RuleItem(
                          '💰',
                          '불법 상업 행위',
                          '무허가 거래, 사기성 홍보, 도박 광고 금지',
                        ),
                        _RuleItem(
                          '📢',
                          '스팸 / 도배',
                          '광고, 같은 글 반복, 무관한 외부 링크 금지',
                        ),
                        _RuleItem(
                          '🚫',
                          '허위 정보 / 사칭',
                          '거짓 조과, 가짜 포인트, 타인 사칭 금지',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 처벌 안내
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.gavel, color: Colors.amber.shade800, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '규칙 위반 시 조치',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _punishItem('1차', '게시글 자동 숨김 + 경고 알림'),
                          _punishItem('2차', '24시간 글쓰기 제한'),
                          _punishItem('3차', '7일 글쓰기 제한'),
                          _punishItem('심각', '영구 이용 정지'),
                          const SizedBox(height: 10),
                          Text(
                            '※ 신고 3건 이상 누적 시 자동 숨김 처리됩니다.\n※ 음란성·정치 분쟁은 1회 위반으로도 즉시 제재될 수 있습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 신고 안내
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EAED)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag, color: _kRed, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '신고 / 차단 기능',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _kNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '• 부적절한 게시글은 우측 상단 메뉴(⋮)에서 신고할 수 있어요.\n'
                            '• 신고는 익명으로 처리되며, 가해자에게 알려지지 않습니다.\n'
                            '• 특정 사용자를 차단하면 그 사람의 글/댓글이 보이지 않아요.\n'
                            '• 차단은 설정에서 언제든 해제할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kSub,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // 동의 버튼 (글쓰기 첫 진입 시만)
            if (widget.requiresAgreement)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _agreed = !_agreed);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _agreed ? _kPrimary.withOpacity(0.08) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _agreed ? _kPrimary : const Color(0xFFE8EAED),
                            width: _agreed ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _agreed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _agreed ? _kPrimary : _kSub,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '위 규칙을 모두 읽었으며, 동의합니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _kNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _agreed
                            ? () async {
                                HapticFeedback.mediumImpact();
                                await CommunityRulesScreen._setAgreed();
                                if (mounted) Navigator.pop(context, true);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '동의하고 시작하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Color color,
    required List<_RuleItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.map((item) => _ruleRow(item, color)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(_RuleItem item, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kSub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _punishItem(String level, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 40, height: 22,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              level,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem {
  final String emoji;
  final String title;
  final String description;
  
  const _RuleItem(this.emoji, this.title, this.description);
}