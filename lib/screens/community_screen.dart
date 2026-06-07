// lib/screens/community_screen.dart
//
// 커뮤니티 메인 화면 — 완성본.
// ✅ Pull-to-refresh / 오프라인 배너 / 검색 / 카테고리 / 정렬
// ✅ 깜빡임 수정: _streamKey 완전 제거 → _cachedPosts 방식으로 교체
// ✅ _PostCard StatefulWidget + AutomaticKeepAlive + 이미지 캐싱

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/offline_banner.dart';
import 'nickname_setup_screen.dart';
import 'post_compose_screen.dart';
import 'post_detail_screen.dart';
import 'community_rules_screen.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF2F4F6);
const Color _kCard = Colors.white;
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kRed = Color(0xFFFF4B4B);
const Color _kOrange = Color(0xFFF97316);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _hasNickname = false;
  bool _checking = true;

  final _searchController = TextEditingController();
  String _searchKeyword = '';
  Timer? _debounce;
  bool _searchVisible = false;

  PostCategory _selectedCategory = PostCategory.all;
  PostSortOption _selectedSort = PostSortOption.latest;

  // ✅ _streamKey 완전 제거.
  // 스트림은 항상 살아있고, 새로고침 시에는 _refreshTrigger를 bump해서
  // PostService가 최신 데이터를 다시 fetch하도록 유도한다.
  // ConnectionState.waiting 으로 빠지지 않으므로 깜빡임 없음.
  int _refreshTrigger = 0;

  // ✅ 마지막으로 받은 포스트 목록 캐시 — 새로고침 중에도 기존 목록 유지
  List<CommunityPost> _cachedPosts = [];
  bool _hasFetched = false;  // 첫 fetch 완료 여부 (빈 목록도 포함)
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _checkNickname();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchKeyword = value);
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _searchKeyword = '';
      }
    });
  }

  Future<void> _onComposeTap() async {
    HapticFeedback.lightImpact();

    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('오프라인 상태에서는 글을 쓸 수 없어요'),
          ]),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    if (!mounted) return;

    final agreed = await CommunityRulesScreen.requireAgreement(context);
    if (!agreed) return;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostComposeScreen()),
    );
  }

  void _showSortSheet() {
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
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('정렬',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _kSub)),
              ),
            ),
            ...PostSortOption.values.map((opt) {
              final isSelected = _selectedSort == opt;
              return ListTile(
                leading: Text(opt.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? _kPrimary : _kNavy,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: _kPrimary)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = opt);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ✅ 새로고침: UniqueKey()로 스트림 끊지 않고 trigger만 bump
  // → StreamBuilder는 ConnectionState.waiting으로 빠지지 않음
  // → _cachedPosts가 유지되므로 기존 목록이 그대로 보임
  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _isRefreshing = true);
    setState(() => _refreshTrigger++);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavHeight = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _kNavy,
        title: const Text(
          '커뮤니티',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          // ✅ 새로고침 중일 때 앱바에 작은 인디케이터 표시 (목록은 그대로)
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search,
                color: Colors.white),
            onPressed: _toggleSearch,
            tooltip: _searchVisible ? '검색 닫기' : '검색',
          ),
        ],
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const OfflineBanner(),
                if (_searchVisible) _buildSearchBar(),
                _buildCategoryTabs(),
                _buildSortRow(),
                const Divider(height: 1, color: _kBorder),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: _kPrimary,
                    child: StreamBuilder<List<CommunityPost>>(
                      // ✅ key 없음 — 스트림을 끊지 않으므로 waiting 상태 없음
                      stream: PostService.instance.watchPosts(
                        searchKeyword: _searchKeyword,
                        sort: _selectedSort,
                        category: _selectedCategory,
                        refreshTrigger: _refreshTrigger,
                      ),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          if (ConnectivityService.instance.isOffline) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: OfflineFullCard(
                                    customMessage:
                                        '인터넷에 연결되면\n커뮤니티 글을 볼 수 있어요',
                                    onRetry: _onRefresh,
                                  ),
                                ),
                              ],
                            );
                          }
                          return _ErrorState(
                            error: snap.error.toString(),
                            onRetry: _onRefresh,
                          );
                        }

                        // ✅ 새 데이터가 오면 캐시 갱신 + 첫 fetch 완료 표시
                        if (snap.hasData) {
                          _cachedPosts = snap.data!;
                          _hasFetched = true;
                        }

                        // ✅ 한 번도 fetch 안 됐을 때만 로딩 UI
                        // _hasFetched = true면 빈 목록이어도 스켈레톤 안 보여줌
                        if (!_hasFetched &&
                            snap.connectionState == ConnectionState.waiting) {
                          return _buildLoadingList();
                        }

                        final posts = _cachedPosts;

                        if (posts.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: _buildEmptyState(),
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          padding:
                              EdgeInsets.only(bottom: bottomNavHeight + 80),
                          itemCount: posts.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: _kBorder,
                              indent: 16,
                              endIndent: 16),
                          itemBuilder: (ctx, i) => _PostCard(
                            key: ValueKey(posts[i].id),
                            post: posts[i],
                            searchKeyword: _searchKeyword,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomNavHeight - 30),
        child: StreamBuilder<NetworkStatus>(
          initialData: ConnectivityService.instance.currentStatus,
          stream: ConnectivityService.instance.statusStream,
          builder: (ctx, snap) {
            final isOffline = snap.data == NetworkStatus.offline;
            return FloatingActionButton.extended(
              backgroundColor: isOffline ? Colors.grey : _kPrimary,
              elevation: 6,
              onPressed: _onComposeTap,
              icon: Icon(
                isOffline ? Icons.wifi_off : Icons.edit,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                isOffline ? '오프라인' : '글쓰기',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: _kNavy),
        decoration: InputDecoration(
          hintText: '제목, 내용, 닉네임, 어종 검색',
          hintStyle: const TextStyle(color: _kSub, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _kSub, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: _kSub, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchKeyword = '');
                  },
                )
              : null,
          filled: true,
          fillColor: _kBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: PostCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            final isMyPosts = cat == PostCategory.myPosts;
            final activeColor = isMyPosts ? _kOrange : _kPrimary;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _kSub,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSortRow() {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
      child: Row(
        children: [
          if (_searchKeyword.isNotEmpty) ...[
            const Icon(Icons.search, size: 14, color: _kPrimary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                "'$_searchKeyword' 검색 결과",
                style: const TextStyle(
                    fontSize: 12,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedSort.emoji,
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    _selectedSort.label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kNavy,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: _kSub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchKeyword.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 12),
              Text(
                "'$_searchKeyword'에 대한 결과가 없어요",
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _kNavy),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '다른 검색어를 시도해보세요',
                style: TextStyle(fontSize: 13, color: _kSub),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedCategory != PostCategory.all) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_selectedCategory.emoji,
                style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 12),
            Text(
              _selectedCategory == PostCategory.myPosts
                  ? '아직 작성한 글이 없어요'
                  : '${_selectedCategory.label} 글이 없어요',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _kNavy),
            ),
            const SizedBox(height: 6),
            const Text(
              '첫 게시글을 작성해보세요!',
              style: TextStyle(fontSize: 13, color: _kSub),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎣', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            '아직 게시글이 없어요',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _onComposeTap,
            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
            label: const Text(
              '첫 게시글 쓰기',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 게시글 카드
// ✅ StatefulWidget + AutomaticKeepAliveClientMixin — 깜빡임 방지
// ✅ 이미지 디코딩 결과 캐싱 — 좋아요/댓글 업데이트 시 이미지 재디코딩 안 함
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PostCard extends StatefulWidget {
  final CommunityPost post;
  final String searchKeyword;

  const _PostCard({
    super.key,
    required this.post,
    this.searchKeyword = '',
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with AutomaticKeepAliveClientMixin {

  Uint8List? _cachedThumb;
  String? _cachedThumbSource;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(_PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newThumbSrc = widget.post.imageBase64Thumbs.isNotEmpty
        ? widget.post.imageBase64Thumbs.first
        : null;
    if (newThumbSrc != _cachedThumbSource) {
      _cachedThumb = null;
      _cachedThumbSource = null;
    }
  }

  Uint8List _getThumbBytes() {
    final src = widget.post.imageBase64Thumbs.first;
    if (_cachedThumbSource == src && _cachedThumb != null) {
      return _cachedThumb!;
    }
    _cachedThumb = base64Decode(src);
    _cachedThumbSource = src;
    return _cachedThumb!;
  }

  void _openDetail(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: widget.post.id)),
    );
  }

  Widget _highlightText(String text, String keyword, TextStyle baseStyle,
      {int? maxLines}) {
    if (keyword.isEmpty) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : null);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final index = lowerText.indexOf(lowerKeyword);

    if (index == -1) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : null);
    }

    return RichText(
      maxLines: maxLines,
      overflow:
          maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + keyword.length),
            style: baseStyle.copyWith(
              backgroundColor: const Color(0xFFFFF59D),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + keyword.length)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'question': return const Color(0xFFF97316);
      case 'info':     return const Color(0xFF03C75A);
      case 'catch':
      default:         return _kPrimary;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'question': return '❓';
      case 'info':     return '💡';
      case 'catch':
      default:         return '🎣';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final post = widget.post;
    final categoryColor = _getCategoryColor(post.category);
    final categoryEmoji = _getCategoryEmoji(post.category);

    return InkWell(
      onTap: () => _openDetail(context),
      child: Container(
        color: _kCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: categoryColor.withOpacity(0.3), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        post.nickname.isNotEmpty
                            ? post.nickname.substring(0, 1)
                            : '?',
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          categoryEmoji,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    post.nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kNavy),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${post.timeAgo}',
                  style: const TextStyle(fontSize: 12, color: _kSub),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlightText(
                        post.title,
                        widget.searchKeyword,
                        const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kNavy,
                          height: 1.3,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      _highlightText(
                        post.body,
                        widget.searchKeyword,
                        const TextStyle(
                            fontSize: 13, color: _kSub, height: 1.4),
                        maxLines: 2,
                      ),
                      if (post.linkedFishName != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '#${post.linkedFishName}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: _kPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (post.hasImage) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _getThumbBytes(),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: _kSub),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.favorite, size: 14, color: _kSub),
                const SizedBox(width: 4),
                Text('${post.likeCount}', style: const TextStyle(fontSize: 12, color: _kSub)),
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble, size: 14, color: _kSub),
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

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  const _ErrorState({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: _kRed, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    '게시글을 불러올 수 없어요',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kNavy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: _kSub),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary),
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 16),
                      label: const Text('다시 시도',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}