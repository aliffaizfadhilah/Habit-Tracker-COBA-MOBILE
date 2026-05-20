import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/post_repository.dart';
import '../../domain/post_model.dart';
import '../providers/post_provider.dart';
import 'post_wizard_screen.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────
String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return DateFormat('d MMM yyyy', 'id').format(dt);
  } catch (_) {
    return '';
  }
}

// ── Feed Screen ────────────────────────────────────────────────────────────────
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Post> _filter(List<Post> posts) {
    if (_search.isEmpty) return posts;
    final q = _search.toLowerCase();
    return posts.where((p) =>
        p.title.toLowerCase().contains(q) ||
        (p.caption?.toLowerCase().contains(q) ?? false) ||
        (p.habitTitle?.toLowerCase().contains(q) ?? false) ||
        p.user.displayName.toLowerCase().contains(q) ||
        p.user.username.toLowerCase().contains(q)).toList();
  }

  void _openDetail(Post post) {
    final currentUser = ref.read(currentUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(
        post: post,
        isOwner: currentUser?.id == post.user.id,
        onLikeToggled: () => ref.read(feedProvider.notifier).toggleLike(post.id),
        onDeleted: () => ref.read(feedProvider.notifier).deletePost(post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.feed_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Feed',
                  style: GoogleFonts.syne(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              Text('Progres habit semua pengguna',
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostWizardScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Cari postingan, habit, atau pengguna...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: feedAsync.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => ErrorWidget2(
                message: 'Gagal memuat feed',
                onRetry: () => ref.read(feedProvider.notifier).load(),
              ),
              data: (allPosts) {
                final posts = _filter(allPosts);

                if (allPosts.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                            color: AppColors.primaryLighter,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.feed_outlined, size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text('Belum ada postingan',
                          style: GoogleFonts.syne(
                              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Text('Jadilah yang pertama berbagi progres!',
                          style: GoogleFonts.dmSans(color: AppColors.muted)),
                    ]),
                  );
                }

                if (posts.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                            color: AppColors.primaryLighter,
                            borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.search_off_rounded, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(height: 14),
                      Text('Tidak ditemukan',
                          style: GoogleFonts.syne(
                              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Tidak ada postingan yang cocok dengan "$_search"',
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.read(feedProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      _MasonryGrid(
                        posts: posts,
                        onTap: _openDetail,
                        onLike: (p) => ref.read(feedProvider.notifier).toggleLike(p.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2-column Masonry Grid ──────────────────────────────────────────────────────
class _MasonryGrid extends StatelessWidget {
  final List<Post> posts;
  final ValueChanged<Post> onTap;
  final ValueChanged<Post> onLike;

  const _MasonryGrid({required this.posts, required this.onTap, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final col0 = <Post>[];
    final col1 = <Post>[];
    for (int i = 0; i < posts.length; i++) {
      if (i % 2 == 0) {
        col0.add(posts[i]);
      } else {
        col1.add(posts[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: col0
                .map((p) => _PinCard(
                      post: p,
                      onTap: () => onTap(p),
                      onLike: () => onLike(p),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: col1
                .map((p) => _PinCard(
                      post: p,
                      onTap: () => onTap(p),
                      onLike: () => onLike(p),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Pin Card ───────────────────────────────────────────────────────────────────
class _PinCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _PinCard({required this.post, required this.onTap, required this.onLike});

  @override
  Widget build(BuildContext context) =>
      post.isCircular ? _buildCircular() : _buildRect();

  Widget _buildCircular() => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipOval(
                        child: post.imageUrl != null
                            ? Image.network(post.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _circlePlaceholder())
                            : _circlePlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onLike,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: post.likedByMe
                                ? AppColors.error
                                : Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4)
                            ],
                          ),
                          child: Icon(
                            post.likedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 14,
                            color: post.likedByMe ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    Text(
                      post.title,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post.caption != null && post.caption!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        post.caption!,
                        style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildRect() => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  post.imageUrl != null
                      ? Image.network(
                          post.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => _rectPlaceholder(),
                        )
                      : _rectPlaceholder(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onLike,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: post.likedByMe
                              ? AppColors.error
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6)
                          ],
                        ),
                        child: Icon(
                          post.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color: post.likedByMe ? Colors.white : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (post.title.isNotEmpty || (post.caption?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.title.isNotEmpty)
                        Text(
                          post.title,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (post.caption != null && post.caption!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.caption!,
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _circlePlaceholder() => Container(
        color: const Color(0xFFdcfce7),
        child: const Center(
            child: Icon(Icons.bar_chart_rounded, size: 28, color: AppColors.primary)),
      );

  Widget _rectPlaceholder() => Container(
        height: 120,
        color: const Color(0xFFdcfce7),
        child: const Center(
            child: Icon(Icons.bar_chart_rounded, size: 28, color: AppColors.primary)),
      );
}

// ── Post Detail Sheet ──────────────────────────────────────────────────────────
class _PostDetailSheet extends ConsumerStatefulWidget {
  final Post post;
  final bool isOwner;
  final VoidCallback onLikeToggled;
  final Future<void> Function() onDeleted;

  const _PostDetailSheet({
    required this.post,
    required this.isOwner,
    required this.onLikeToggled,
    required this.onDeleted,
  });

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  late bool _liked;
  late int _likesCount;
  late int _commentsCount;
  final _commentCtrl = TextEditingController();
  final List<Comment> _comments = [];
  bool _loadingComments = true;
  bool _sending = false;
  bool _confirmDelete = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await ref.read(postRepositoryProvider).getComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments.addAll(list);
          _commentsCount = list.length;
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final newLiked = !_liked;
    setState(() {
      _liked = newLiked;
      _likesCount += newLiked ? 1 : -1;
    });
    try {
      await ref.read(postRepositoryProvider).toggleLike(widget.post.id);
      widget.onLikeToggled(); // update feed list
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !newLiked;
          _likesCount += newLiked ? -1 : 1;
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment =
          await ref.read(postRepositoryProvider).addComment(widget.post.id, text);
      _commentCtrl.clear();
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _commentsCount++;
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _removeComment(Comment comment) async {
    try {
      await ref
          .read(postRepositoryProvider)
          .deleteComment(widget.post.id, comment.id);
      if (mounted) {
        setState(() {
          _comments.remove(comment);
          _commentsCount = (_commentsCount - 1).clamp(0, 9999);
        });
      }
    } catch (_) {}
  }

  Future<void> _deletePost() async {
    setState(() => _deleting = true);
    try {
      await widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _deleting = false; _confirmDelete = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider);
    final screenH = MediaQuery.of(context).size.height;
    final p = widget.post;

    return Container(
      height: screenH * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),

          // ── Top action bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: const Color(0xFFf3f4f6),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.ink),
                  ),
                ),
                const Spacer(),
                // Like button
                GestureDetector(
                  onTap: _toggleLike,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _liked ? const Color(0xFFfef2f2) : const Color(0xFFf3f4f6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Icon(
                        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: _liked ? AppColors.error : AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text('$_likesCount',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _liked ? AppColors.error : AppColors.muted)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Comment count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFf3f4f6),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 15, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text('$_commentsCount',
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ]),
                ),
                if (widget.isOwner) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _confirmDelete = true),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: const Color(0xFFfef2f2),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  _buildImage(p),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & caption
                        Text(p.title,
                            style: GoogleFonts.syne(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        if (p.caption != null && p.caption!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(p.caption!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: AppColors.muted,
                                  height: 1.5)),
                        ],
                        const SizedBox(height: 12),

                        // Habit badge
                        if (p.habitTitle != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf0fdf4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(children: [
                                    const Icon(Icons.bar_chart_rounded,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        p.habitTitle!,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ]),
                                ),
                                if (p.progressPercent != null)
                                  Text(
                                    '${p.progressPercent!.toStringAsFixed(0)}%',
                                    style: GoogleFonts.syne(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // User info
                        Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              p.user.initials,
                              style: GoogleFonts.syne(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.user.displayName,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink)),
                              Text(
                                '@${p.user.username} · ${_formatDate(p.createdAt)}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),

                        // Comments header
                        Text('$_commentsCount Komentar',
                            style: GoogleFonts.syne(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        const SizedBox(height: 12),

                        // Comments list
                        if (_loadingComments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Memuat komentar...',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: AppColors.muted)),
                          )
                        else if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Belum ada komentar.',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontStyle: FontStyle.italic)),
                          )
                        else
                          ..._comments.map((c) => _CommentTile(
                                comment: c,
                                isOwner: currentUser?.id == c.user.id,
                                onDelete: () => _removeComment(c),
                              )),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Delete confirm ─────────────────────────────────────────────────
          if (_confirmDelete)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFfef2f2),
                border: Border(top: BorderSide(color: Color(0xFFfecaca))),
              ),
              child: Column(
                children: [
                  Text('Hapus postingan ini? Tidak dapat dikembalikan.',
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _confirmDelete = false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Batal',
                            style: GoogleFonts.dmSans(color: AppColors.muted)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _deleting ? null : _deletePost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _deleting
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Ya, Hapus',
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

          // ── Comment input ──────────────────────────────────────────────────
          if (!_confirmDelete)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar...',
                        hintStyle: GoogleFonts.dmSans(
                            color: AppColors.subtle, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendComment,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(19)),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(Post p) {
    if (p.isCircular) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 200, height: 200,
            child: ClipOval(
              child: p.imageUrl != null
                  ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder(isCircle: true))
                  : _imgPlaceholder(isCircle: true),
            ),
          ),
        ),
      );
    }
    if (p.imageUrl == null) return const SizedBox.shrink();
    return Image.network(
      p.imageUrl!,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }

  Widget _imgPlaceholder({bool isCircle = false}) => Container(
        height: isCircle ? null : 220,
        color: const Color(0xFFdcfce7),
        child: const Center(
            child: Icon(Icons.bar_chart_rounded, size: 44, color: AppColors.primary)),
      );
}

// ── Comment Tile ───────────────────────────────────────────────────────────────
class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isOwner;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              comment.user.initials,
              style: GoogleFonts.syne(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf8f8f8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.user.displayName,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.content,
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.inkBody),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      Text(
                        _formatDate(comment.createdAt),
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppColors.muted),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: onDelete,
                          child: Text('Hapus',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: AppColors.error)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
