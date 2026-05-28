// lib/widgets/report_block_dialogs.dart
//
// 신고/차단 다이얼로그 v2.
// ✅ 성/정치/홍보 사유 추가
// ✅ 더 구체적인 가이드

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/post_service.dart';
import '../services/block_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);

/// 신고 사유 옵션
class _ReportReason {
  final String code;
  final String label;
  final String emoji;
  final String description;
  
  const _ReportReason({
    required this.code,
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// ✅ 사유 8가지로 확대
const List<_ReportReason> _kReportReasons = [
  _ReportReason(
    code: 'spam',
    label: '스팸/광고',
    emoji: '📢',
    description: '광고, 도배, 같은 글 반복',
  ),
  _ReportReason(
    code: 'inappropriate',
    label: '욕설/비방',
    emoji: '🤬',
    description: '욕설, 인신공격, 비방, 혐오 발언',
  ),
  _ReportReason(
    code: 'sexual',
    label: '음란성/성희롱',
    emoji: '🔞',
    description: '음란한 사진·내용, 성적 발언, 성희롱',
  ),
  _ReportReason(
    code: 'politics',
    label: '정치/종교 분쟁',
    emoji: '⚖️',
    description: '정치 선동, 종교 갈등 조장, 분쟁 유도',
  ),
  _ReportReason(
    code: 'fake_info',
    label: '허위 정보',
    emoji: '🚫',
    description: '거짓 조과, 가짜 포인트 정보, 사기',
  ),
  _ReportReason(
    code: 'illegal_fishing',
    label: '불법 어업',
    emoji: '⚠️',
    description: '금어기 위반, 금지체장 미달, 불법 장비',
  ),
  _ReportReason(
    code: 'commercial',
    label: '불법 상업 행위',
    emoji: '💰',
    description: '불법 판매, 무허가 거래, 사기성 홍보',
  ),
  _ReportReason(
    code: 'other',
    label: '기타',
    emoji: '💬',
    description: '직접 입력',
  ),
];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 신고 다이얼로그
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ReportDialog extends StatefulWidget {
  final String postId;
  final String postTitle;
  final String authorNickname;
  
  const ReportDialog({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.authorNickname,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String postId,
    required String postTitle,
    required String authorNickname,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReportDialog(
        postId: postId,
        postTitle: postTitle,
        authorNickname: authorNickname,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  _ReportReason? _selected;
  final _customReasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    
    String reason;
    if (_selected!.code == 'other') {
      final custom = _customReasonCtrl.text.trim();
      if (custom.length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고 사유를 5자 이상 입력해주세요'),
            backgroundColor: _kRed,
          ),
        );
        return;
      }
      reason = '${_selected!.label}: $custom';
    } else {
      reason = '${_selected!.label} (${_selected!.description})';
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      await PostService.instance.reportPost(widget.postId, reason);
      
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('신고가 접수됐어요. 검토 후 조치할게요.')),
          ]),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.flag, color: _kRed, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '게시글 신고',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // 안내 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
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
                        '신고는 익명으로 처리되며, 3건 이상 누적 시 자동 숨김 처리됩니다.',
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
            ),
            const SizedBox(height: 16),
            
            // 사유 선택
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고 사유를 선택해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    ..._kReportReasons.map((reason) {
                      final isSelected = _selected?.code == reason.code;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = reason);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? _kRed.withOpacity(0.05) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _kRed : _kBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(reason.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reason.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? _kRed : _kNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reason.description,
                                      style: const TextStyle(fontSize: 11, color: _kSub),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: _kRed, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                    
                    // "기타" 선택 시 직접 입력
                    if (_selected?.code == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customReasonCtrl,
                        maxLength: 200,
                        maxLines: 3,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '신고 사유를 자세히 적어주세요 (5자 이상)',
                          hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _kBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kRed, width: 1.5),
                          ),
                          counterStyle: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소', style: TextStyle(color: _kSub)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selected == null || _submitting) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRed,
                        disabledBackgroundColor: Colors.grey[300],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '신고하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 차단 다이얼로그 (기존과 동일)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BlockDialog extends StatelessWidget {
  final String targetUid;
  final String targetNickname;
  
  const BlockDialog({
    super.key,
    required this.targetUid,
    required this.targetNickname,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetUid,
    required String targetNickname,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => BlockDialog(
        targetUid: targetUid,
        targetNickname: targetNickname,
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      await BlockService.blockUser(targetUid);
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.block, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text("'$targetNickname'님을 차단했어요")),
          ]),
          backgroundColor: _kNavy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('차단 실패: $e'),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: _kNavy.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.block, color: _kNavy, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              '사용자 차단',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _kNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                targetNickname,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _kNavy,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '차단하면 어떻게 되나요?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _kNavy,
                    ),
                  ),
                  SizedBox(height: 6),
                  _BlockEffect(emoji: '🚫', text: '이 사용자의 게시글이 보이지 않아요'),
                  _BlockEffect(emoji: '💬', text: '이 사용자의 댓글이 보이지 않아요'),
                  _BlockEffect(emoji: '⚙️', text: '설정에서 언제든 해제할 수 있어요'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('취소', style: TextStyle(color: _kSub)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmBlock(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '차단하기',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockEffect extends StatelessWidget {
  final String emoji;
  final String text;
  const _BlockEffect({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: _kSub),
            ),
          ),
        ],
      ),
    );
  }
}