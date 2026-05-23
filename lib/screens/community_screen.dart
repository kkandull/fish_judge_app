// lib/screens/community_screen.dart
//
// 커뮤니티 메인 — 게시글 목록 + 작성 FAB.
//
// 진입 시 닉네임 없으면 NicknameSetupScreen으로 유도.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import 'nickname_setup_screen.dart';
import 'post_compose_screen.dart';
import 'post_detail_screen.dart';

const Color _kPrimary = Color(0xFF007AFF);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kCard = Colors.white;
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _hasNickname = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkNickname();
  }

  Future<void> _checkNickname() async {
    final has = await AuthService.instance.hasNickname();
    if (mounted) {
      setState(() {
        _hasNickname = has;
        _checking = false;
      });
    }
  }

  Future<void> _onComposeTap() async {
    HapticFeedback.lightImpact();
    
    // 닉네임 없으면 먼저 설정
    if (!_hasNickname) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const NicknameSetupScreen()),
      );
      if (result == true) {
        setState(() => _hasNickname = true);
      } else {
        return;
      }
    }
    
    // 작성 화면
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostComposeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      // ⚠️ extendBody: false (기본값) — FAB가 nav bar 위로 올라감
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _kNavy,
        title: const Text(
          '커뮤니티',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('검색 기능 준비 중')),
              );
            },
          ),
        ],
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<CommunityPost>>(
              stream: PostService.instance.watchPosts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorState(error: snap.error.toString());
                }
                final posts = snap.data ?? [];
                if (posts.isEmpty) {
                  return _EmptyState(onCompose: _onComposeTap);
                }
                return RefreshIndicator(
                  color: _kPrimary,
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // ⚠️ FAB + nav bar 공간 확보 (180 = FAB 60 + nav bar 80 + 여유 40)
                    padding: const EdgeInsets.only(bottom: 180),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
                    itemBuilder: (ctx, i) => _PostCard(post: posts[i]),
                  ),
                );
              },
            ),
      // ⚠️ FAB 위치를 BottomNavigationBar 위로 올림
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // 하단 nav bar 높이(약 80px)만큼 위로 올림
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          backgroundColor: _kPrimary,
          elevation: 8,
          onPressed: _onComposeTap,
          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
          label: const Text(
            '글쓰기',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 게시글 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  void _openDetail(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      child: Container(
        color: _kCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 닉네임 + 시간
            Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    post.nickname.isNotEmpty ? post.nickname.substring(0, 1) : '?',
                    style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  post.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kNavy),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${post.timeAgo}',
                  style: const TextStyle(fontSize: 12, color: _kSub),
                ),
                const Spacer(),
                if (post.linkedFishName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${post.linkedFishName}',
                      style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 본문 + 이미지
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kNavy,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.body,
                        style: const TextStyle(fontSize: 13, color: _kSub, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (post.hasImage) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(post.imageBase64Thumb!),
                      width: 72, height: 72, fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72, height: 72,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: _kSub),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // 좋아요/댓글 카운트
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 14, color: _kSub),
                const SizedBox(width: 4),
                Text('${post.likeCount}', style: const TextStyle(fontSize: 12, color: _kSub)),
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline, size: 14, color: _kSub),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: _kSub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 빈 상태
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EmptyState extends StatelessWidget {
  final VoidCallback onCompose;
  const _EmptyState({required this.onCompose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎣', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            '아직 게시글이 없어요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            '첫 게시글의 주인공이 되어보세요!',
            style: TextStyle(fontSize: 14, color: _kSub),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onCompose,
            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
            label: const Text(
              '첫 게시글 쓰기',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 48),
            const SizedBox(height: 12),
            const Text(
              '게시글을 불러올 수 없어요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _kSub),
            ),
          ],
        ),
      ),
    );
  }
}