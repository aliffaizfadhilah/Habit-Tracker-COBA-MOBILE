import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/post_repository.dart';
import '../../domain/post_model.dart';
import '../providers/post_provider.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  final Post post;
  const CommentsScreen({super.key, required this.post});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(postRepositoryProvider).addComment(widget.post.id, text);
      _ctrl.clear();
      ref.invalidate(commentsProvider(widget.post.id));
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Komentar')),
      body: Column(
        children: [
          // Post body
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.title,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                if (widget.post.caption != null && widget.post.caption!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.post.caption!,
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: AppColors.inkBody, height: 1.5),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const Center(child: Text('Gagal memuat komentar')),
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada komentar. Jadilah yang pertama!',
                      style: GoogleFonts.dmSans(color: AppColors.muted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (_, i) => _CommentTile(
                    comment: comments[i],
                    isOwner: currentUser?.id == comments[i].user.id,
                    onDelete: () async {
                      await ref.read(postRepositoryProvider).deleteComment(
                            widget.post.id,
                            comments[i].id,
                          );
                      ref.invalidate(commentsProvider(widget.post.id));
                    },
                  ),
                );
              },
            ),
          ),

          // Input
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
            child: Row(
              children: [
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
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'Tulis komentar...',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.subtle, fontSize: 14),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              comment.user.initials,
              style: GoogleFonts.syne(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.user.displayName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.content,
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkBody),
                  ),
                ],
              ),
            ),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.subtle),
              onPressed: onDelete,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
