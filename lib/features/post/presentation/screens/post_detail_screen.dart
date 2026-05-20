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

String _timeAgo(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return DateFormat('d MMM yyyy', 'id').format(dt);
  } catch (_) {
    return '';
  }
}

class PostDetailScreen extends ConsumerStatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late Post _post;
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _liking = false;
  bool _confirmDelete = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    final liked = !_post.likedByMe;
    setState(() {
      _liking = true;
      _post = _post.copyWith(
        likedByMe: liked,
        likesCount: _post.likesCount + (liked ? 1 : -1),
      );
    });
    try {
      await ref.read(postRepositoryProvider).toggleLike(_post.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _post = _post.copyWith(
            likedByMe: !liked,
            likesCount: _post.likesCount + (liked ? -1 : 1),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(postRepositoryProvider).addComment(_post.id, text);
      _ctrl.clear();
      setState(() => _post = _post.copyWith(commentsCount: _post.commentsCount + 1));
      ref.invalidate(commentsProvider(_post.id));
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deletePost() async {
    setState(() => _deleting = true);
    try {
      await ref.read(postRepositoryProvider).deletePost(_post.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() { _deleting = false; _confirmDelete = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(_post.id));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          _post.title,
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          InkWell(
            onTap: _toggleLike,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _post.likedByMe ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  size: 19,
                  color: _post.likedByMe ? AppColors.error : AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text('${_post.likesCount}',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${_post.commentsCount}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
          if (_post.isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
              tooltip: 'Hapus',
              onPressed: () => setState(() => _confirmDelete = true),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Gambar ──
                SliverToBoxAdapter(
                  child: _post.imageUrl != null
                      ? Image.network(
                          _post.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => Container(
                            height: 220,
                            color: AppColors.primaryLighter,
                            child: const Icon(Icons.image_outlined,
                                size: 60, color: AppColors.primary),
                          ),
                        )
                      : Container(
                          height: 220,
                          color: AppColors.primaryLighter,
                          child: const Icon(Icons.image_outlined,
                              size: 60, color: AppColors.primary),
                        ),
                ),

                // ── Judul & Konten ──
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_post.title,
                            style: GoogleFonts.syne(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        if (_post.caption != null && _post.caption!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_post.caption!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 14, color: AppColors.muted, height: 1.5)),
                        ],
                        if (_post.habitTitle != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLighter,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.bar_chart_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_post.habitTitle!,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                              if (_post.progressPercent != null)
                                Text(
                                    '${_post.progressPercent!.toStringAsFixed(0)}%',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Info Pengguna ──
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: _post.user.profilePicture != null
                            ? NetworkImage(_post.user.profilePicture!)
                            : null,
                        child: _post.user.profilePicture == null
                            ? Text(_post.user.initials,
                                style: GoogleFonts.syne(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_post.user.displayName,
                            style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        Text(
                          '@${_post.user.username} · ${_timeAgo(_post.createdAt)}',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                        ),
                      ]),
                    ]),
                  ),
                ),

                // ── Konfirmasi Hapus ──
                if (_confirmDelete)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFfecaca)),
                      ),
                      child: Column(children: [
                        Text(
                          'Hapus postingan ini? Tindakan tidak bisa dibatalkan.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _confirmDelete = false),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _deleting ? null : _deletePost,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: _deleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Ya, Hapus'),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),

                // ── Header Komentar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: commentsAsync.when(
                      data: (c) => Text(
                        '${c.length} Komentar',
                        style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                      loading: () => Text('Komentar',
                          style: GoogleFonts.syne(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
                ),

                // ── Daftar Komentar ──
                commentsAsync.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: LoadingWidget()),
                  error: (_, __) => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Gagal memuat komentar'),
                      ),
                    ),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Belum ada komentar. Jadilah yang pertama!',
                              style:
                                  GoogleFonts.dmSans(color: AppColors.muted),
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _CommentTile(
                            comment: comments[i],
                            isOwner:
                                currentUser?.id == comments[i].user.id,
                            onDelete: () async {
                              await ref
                                  .read(postRepositoryProvider)
                                  .deleteComment(_post.id, comments[i].id);
                              setState(() => _post = _post.copyWith(
                                  commentsCount:
                                      _post.commentsCount - 1));
                              ref.invalidate(commentsProvider(_post.id));
                            },
                          ),
                          childCount: comments.length,
                        ),
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // ── Input Komentar ──
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  currentUser?.name.isNotEmpty == true
                      ? currentUser!.name[0].toUpperCase()
                      : 'U',
                  style: GoogleFonts.syne(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar...',
                    hintStyle:
                        GoogleFonts.dmSans(color: AppColors.subtle, fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: AppColors.primary)),
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
                  width: 38,
                  height: 38,
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
            ]),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isOwner;
  final VoidCallback onDelete;
  const _CommentTile(
      {required this.comment, required this.isOwner, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            child: Text(comment.user.initials,
                style: GoogleFonts.syne(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.user.displayName,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(comment.content,
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.inkBody)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(_timeAgo(comment.createdAt),
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.subtle)),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: Text('Hapus',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error)),
                        ),
                      ],
                    ]),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}
