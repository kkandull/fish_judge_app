// lib/screens/post_detail_screen.dart
//
// 게시글 상세 화면.
// - 본문 + 본 이미지 표시
// - 좋아요 토글
// - 댓글 목록 + 작성
// - 본인 글 → 삭제 / 남의 글 → 신고/차단

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/block_service.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kCard = Colors.white;
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);
const Color _kLike = Color(0xFFFF4B4B);

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  bool _sendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    try {
      await PostService.instance.toggleLike(widget.postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _sendComment() async {
    if (_sendingComment) return;
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    
    setState(() => _sendingComment = true);
    try {
      await PostService.instance.addComment(widget.postId, body);
      _commentController.clear();
      FocusScope.of(context).unfocus();
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: _kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _showMoreMenu(CommunityPost post) async {
    final myUid = AuthService.instance.uid;
    final isMine = post.uid == myUid;
    
    HapticFeedback.selectionClick();
    
    await showModalBottomSheet(
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
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _kRed),
                title: const Text('삭제', style: TextStyle(color: _kRed)),
                onTap: () { Navigator.pop(ctx); _confirmDelete(post); },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: _kRed),
                title: const Text('신고', style: TextStyle(color: _kRed)),
                onTap: () { Navigator.pop(ctx); _showReportDialog(post); },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: _kSub),
                title: const Text('이 사용자 차단'),
                onTap: () { Navigator.pop(ctx); _confirmBlock(post); },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('취소'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시글 삭제'),
        content: const Text('정말로 삭제할까요?\n삭제된 게시글은 복구할 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    
    try {
      await PostService.instance.deletePost(post.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제됐어요'), backgroundColor: _kNavy),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _showReportDialog(CommunityPost post) async {
    final reasonController = TextEditingController();
    final reasons = ['욕설/혐오', '광고/스팸', '음란성', '개인정보 노출', '기타'];
    String? selectedReason = reasons.first;
    
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('게시글 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('신고 사유를 선택해주세요', style: TextStyle(fontSize: 13, color: _kSub)),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                title: Text(r, style: const TextStyle(fontSize: 14)),
                value: r,
                groupValue: selectedReason,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (v) => setSheet(() => selectedReason = v),
              )),
              if (selectedReason == '기타') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '신고 사유를 직접 입력해주세요',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                final reason = selectedReason == '기타'
                    ? reasonController.text.trim()
                    : selectedReason;
                if (reason == null || reason.isEmpty) return;
                Navigator.pop(ctx, reason);
              },
              child: const Text('신고', style: TextStyle(color: _kRed, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    
    if (submitted == null) return;
    
    try {
      await PostService.instance.reportPost(post.id, submitted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고 접수됐어요. 검토 후 조치할게요.'), backgroundColor: _kNavy),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _confirmBlock(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용자 차단'),
        content: Text('${post.nickname} 님의 모든 게시글이\n안 보이게 됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('차단', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    
    await BlockService.blockUser(post.uid);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${post.nickname} 님을 차단했어요'), backgroundColor: _kNavy),
      );
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
          '게시글',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: _kNavy),
      ),
      body: StreamBuilder<CommunityPost?>(
        stream: PostService.instance.watchPost(widget.postId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snap.data;
          if (post == null) {
            return const Center(
              child: Text('게시글을 찾을 수 없어요', style: TextStyle(color: _kSub)),
            );
          }
          
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // 게시글 본문
                    SliverToBoxAdapter(
                      child: _PostBody(post: post, onMore: () => _showMoreMenu(post)),
                    ),
                    // 좋아요/댓글 액션 바
                    SliverToBoxAdapter(child: _ActionBar(
                      post: post,
                      onLike: _toggleLike,
                    )),
                    // 댓글 헤더
                    SliverToBoxAdapter(
                      child: Container(
                        color: _kCard,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 16, color: _kNavy),
                            const SizedBox(width: 6),
                            Text(
                              '댓글 ${post.commentCount}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kNavy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 댓글 목록
                    StreamBuilder<List<Comment>>(
                      stream: PostService.instance.watchComments(widget.postId),
                      builder: (context, csnap) {
                        if (!csnap.hasData) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }
                        final comments = csnap.data!;
                        if (comments.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text('첫 댓글을 남겨보세요!',
                                    style: TextStyle(color: _kSub)),
                              ),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _CommentTile(
                              postId: widget.postId,
                              comment: comments[i],
                            ),
                            childCount: comments.length,
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
              _CommentInput(
                controller: _commentController,
                focusNode: _commentFocus,
                onSend: _sendComment,
                sending: _sendingComment,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 본문 표시
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PostBody extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onMore;
  const _PostBody({required this.post, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 정보 + 더보기
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  post.nickname.isNotEmpty ? post.nickname.substring(0, 1) : '?',
                  style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.nickname,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kNavy)),
                  Text(post.timeAgo,
                    style: const TextStyle(fontSize: 12, color: _kSub)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert, color: _kSub),
                onPressed: onMore,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 어종 태그
          if (post.linkedFishName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${post.linkedFishName}',
                style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // 제목
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: _kNavy, height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          
          // 이미지 (본)
          if (post.imageBase64Full != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(post.imageBase64Full!),
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image, color: _kSub)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // 본문
          Text(
            post.body,
            style: const TextStyle(fontSize: 15, color: _kNavy, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 좋아요/댓글 액션 바
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ActionBar extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  const _ActionBar({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StreamBuilder<bool>(
                stream: PostService.instance.watchLiked(post.id),
                builder: (context, snap) {
                  final liked = snap.data ?? false;
                  return InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? _kLike : _kSub,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likeCount}',
                            style: TextStyle(
                              fontSize: 14,
                              color: liked ? _kLike : _kSub,
                              fontWeight: liked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(width: 1, height: 24, color: _kBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: _kSub, size: 22),
                    const SizedBox(width: 6),
                    Text('${post.commentCount}',
                        style: const TextStyle(fontSize: 14, color: _kSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: _kBorder, height: 1),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 댓글 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CommentTile extends StatelessWidget {
  final String postId;
  final Comment comment;
  const _CommentTile({required this.postId, required this.comment});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    
    try {
      await PostService.instance.deleteComment(postId, comment.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = comment.uid == AuthService.instance.uid;
    
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              comment.nickname.isNotEmpty ? comment.nickname.substring(0, 1) : '?',
              style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kNavy)),
                    const SizedBox(width: 8),
                    Text(comment.timeAgo, style: const TextStyle(fontSize: 11, color: _kSub)),
                    const Spacer(),
                    if (isMine)
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline, size: 16, color: _kSub),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 댓글 입력
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool sending;
  
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: 500,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요',
                  hintStyle: const TextStyle(color: _kSub, fontSize: 14),
                  filled: true,
                  fillColor: _kBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: sending ? null : onSend,
                child: Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  child: sending
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
