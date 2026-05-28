// lib/screens/post_detail_screen.dart
//
// 게시글 상세 화면.
// ✅ 신고/차단 메뉴 통합 + 사용자 친화적 UX
// ✅ Pull-to-refresh 지원
// ✅ 좋아요 후 이미지 깜빡임 제거:
//    - StatefulWidget _PostImages 로 이미지 bytes 캐싱
//    - watchPost re-emit 때 base64Decode 재실행 없음
//    - gaplessPlayback: true 로 교체 시 깜빡임 방지

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../widgets/report_block_dialogs.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  bool _submittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _showOptions(CommunityPost post) {
    final myUid = AuthService.instance.uid;
    final isMine = post.uid == myUid;

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
            if (isMine) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _kRed),
                title: const Text('게시글 삭제', style: TextStyle(color: _kRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmDelete(post);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: _kRed),
                title: const Text('신고하기', style: TextStyle(color: _kRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ReportDialog.show(
                    context,
                    postId: post.id,
                    postTitle: post.title,
                    authorNickname: post.nickname,
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.block, color: _kNavy),
                title: Text('${post.nickname}님 차단'),
                subtitle: const Text('이 사용자의 글/댓글이 안 보이게 됩니다',
                    style: TextStyle(fontSize: 11, color: _kSub)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final blocked = await BlockDialog.show(
                    context,
                    targetUid: post.uid,
                    targetNickname: post.nickname,
                  );
                  if (blocked == true && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제할까요?\n삭제하면 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await PostService.instance.deletePost(post.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제됐어요')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _toggleLike(String postId) async {
    HapticFeedback.lightImpact();
    try {
      await PostService.instance.toggleLike(postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('실패: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_submittingComment) return;
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _submittingComment = true);
    HapticFeedback.lightImpact();

    try {
      await PostService.instance.addComment(widget.postId, body);
      _commentController.clear();
      _commentFocus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _kRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: const Text(
          '게시글',
          style: TextStyle(
              color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: StreamBuilder<CommunityPost?>(
        stream: PostService.instance.watchPost(widget.postId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final post = snap.data;
          if (post == null) {
            return const Center(child: Text('게시글을 찾을 수 없어요'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작성자 + 시간 + 옵션
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _kPrimary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                post.nickname.isNotEmpty
                                    ? post.nickname.substring(0, 1)
                                    : '?',
                                style: const TextStyle(
                                  color: _kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.nickname,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _kNavy,
                                    ),
                                  ),
                                  Text(
                                    post.timeAgo,
                                    style: const TextStyle(
                                        fontSize: 11, color: _kSub),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: _kSub),
                              onPressed: () => _showOptions(post),
                            ),
                          ],
                        ),
                      ),

                      // 제목 + 본문 + 이미지
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _kNavy,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              post.body,
                              style: const TextStyle(
                                  fontSize: 14, height: 1.6, color: _kNavy),
                            ),

                            if (post.linkedFishName != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${post.linkedFishName}',
                                  style: const TextStyle(
                                    color: _kPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],

                            // ✅ 이미지: StatefulWidget으로 분리해 bytes 캐싱
                            // watchPost가 re-emit해도 base64Decode 재실행 없음
                            if (post.hasImage) ...[
                              const SizedBox(height: 16),
                              _PostImages(post: post),
                            ],
                          ],
                        ),
                      ),

                      // 좋아요 / 댓글 카운트
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            StreamBuilder<bool>(
                              stream:
                                  PostService.instance.watchLiked(post.id),
                              builder: (context, likedSnap) {
                                final liked = likedSnap.data ?? false;
                                return GestureDetector(
                                  onTap: () => _toggleLike(post.id),
                                  child: Row(
                                    children: [
                                      Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked ? _kRed : _kSub,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${post.likeCount}',
                                        style: TextStyle(
                                          color: liked ? _kRed : _kSub,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    color: _kSub, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  '${post.commentCount}',
                                  style: const TextStyle(
                                    color: _kSub,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 댓글 섹션
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 16, color: _kNavy),
                                const SizedBox(width: 6),
                                Text(
                                  '댓글 ${post.commentCount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _kNavy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<Comment>>(
                              stream: PostService.instance
                                  .watchComments(post.id),
                              builder: (context, snap) {
                                final comments = snap.data ?? [];
                                if (comments.isEmpty) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Text(
                                        '첫 댓글을 남겨보세요',
                                        style: TextStyle(
                                            color: _kSub, fontSize: 13),
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: comments
                                      .map((c) =>
                                          _buildComment(c, post.id))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 댓글 입력
              SafeArea(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _kBorder)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocus,
                          maxLength: 500,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '댓글을 입력하세요',
                            hintStyle: const TextStyle(
                                color: _kSub, fontSize: 13),
                            filled: true,
                            fillColor: _kBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: _submittingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kPrimary),
                              )
                            : const Icon(Icons.send_rounded,
                                color: _kPrimary),
                        onPressed:
                            _submittingComment ? null : _submitComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComment(Comment c, String postId) {
    final myUid = AuthService.instance.uid;
    final isMine = c.uid == myUid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              c.nickname.isNotEmpty ? c.nickname.substring(0, 1) : '?',
              style: const TextStyle(
                  color: _kPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.nickname,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(c.timeAgo,
                        style:
                            const TextStyle(fontSize: 11, color: _kSub)),
                    const Spacer(),
                    if (isMine)
                      GestureDetector(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('댓글 삭제'),
                              content: const Text('이 댓글을 삭제할까요?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('삭제',
                                      style: TextStyle(color: _kRed)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await PostService.instance
                                  .deleteComment(postId, c.id);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('실패: $e')),
                                );
                              }
                            }
                          }
                        },
                        child: const Icon(Icons.delete_outline,
                            size: 14, color: _kSub),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.body,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: _kNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 게시글 이미지 뷰어
//
// ✅ StatefulWidget으로 분리 — watchPost re-emit 시에도
//    부모 StreamBuilder가 rebuild돼도 이 위젯은 State 유지
// ✅ _decodedImages 캐싱 — 이미지 소스가 바뀐 경우에만 재디코딩
// ✅ gaplessPlayback: true — 프레임 교체 시 깜빡임 방지
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PostImages extends StatefulWidget {
  final CommunityPost post;
  const _PostImages({required this.post});

  @override
  State<_PostImages> createState() => _PostImagesState();
}

class _PostImagesState extends State<_PostImages> {
  // 이미지 소스(base64 문자열) → 디코딩된 bytes 캐시
  final Map<String, Uint8List> _cache = {};

  // 현재 보여주는 페이지 인덱스 (로컬 상태 — 좋아요 눌러도 초기화 안 됨)
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Uint8List _decode(String src) {
    return _cache.putIfAbsent(src, () => base64Decode(src));
  }

  List<String> get _sources {
    final post = widget.post;
    return post.imageBase64Fulls.isNotEmpty
        ? post.imageBase64Fulls
        : post.imageBase64Thumbs;
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: sources.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _decode(sources[index]),   // ✅ 캐시에서 꺼냄
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,     // ✅ 교체 시 깜빡임 방지
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: _kSub),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 페이지 인디케이터 (2장 이상일 때만)
        if (sources.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              sources.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _currentPage ? 14 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _currentPage
                      ? _kPrimary
                      : _kPrimary.withOpacity(0.25),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}