import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/post_repository.dart';
import '../../domain/post_model.dart';
import '../../../../core/network/sse_client.dart';
import '../../../../core/constants/api_constants.dart';

// Feed posts with SSE (falls back to polling every 30 s on error)
class FeedNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  final PostRepository _repo;
  SseClient? _sseClient;
  Timer? _fallbackTimer;

  FeedNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
    _startSSE();
  }

  void _startSSE() {
    _stopSSE();
    _sseClient = SseClient(
      dio: _repo.dio,
      path: ApiConstants.feedStream,
      onEvent: (event, data) {
        if (event != 'new_posts' || !mounted) return;
        try {
          final payload = jsonDecode(data) as Map<String, dynamic>;
          final incoming = (payload['posts'] as List)
              .map((e) => Post.fromJson(e as Map<String, dynamic>))
              .toList();
          if (incoming.isEmpty) return;
          final current = state.valueOrNull ?? [];
          final seen = {for (final p in current) p.id};
          final fresh = incoming.where((p) => !seen.contains(p.id)).toList();
          if (fresh.isNotEmpty) {
            state = AsyncValue.data([...fresh, ...current]);
          }
        } catch (_) {}
      },
    );
    unawaited(_runSSELoop());
  }

  Future<void> _runSSELoop() async {
    var delay = 2;
    while (mounted) {
      final client = _sseClient;
      if (client == null) break;
      try {
        await client.connect();
        delay = 2;
      } on DioException catch (e) {
        if (!mounted || e.type == DioExceptionType.cancel) break;
        _fallbackTimer ??= Timer.periodic(
          const Duration(seconds: 30),
          (_) { if (mounted) _silentRefresh(); },
        );
        await Future.delayed(Duration(seconds: delay));
        _fallbackTimer?.cancel();
        _fallbackTimer = null;
        delay = (delay * 2).clamp(2, 60);
      } catch (_) {
        if (!mounted) break;
        await Future.delayed(Duration(seconds: delay));
        delay = (delay * 2).clamp(2, 60);
      }
    }
  }

  void _stopSSE() {
    _sseClient?.close();
    _sseClient = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getPosts);
  }

  Future<void> _silentRefresh() async {
    try {
      final posts = await _repo.getPosts();
      if (mounted) state = AsyncValue.data(posts);
    } catch (_) {
      // keep showing stale data
    }
  }

  Future<void> addPost({
    required String title,
    String? caption,
    required String imagePath,
    String frameStyle = 'rect',
    int? habitId,
    String? habitTitle,
    double? progressPercent,
    bool isPrivate = false,
  }) async {
    final post = await _repo.createPost(
      title: title,
      caption: caption,
      imagePath: imagePath,
      frameStyle: frameStyle,
      habitId: habitId,
      habitTitle: habitTitle,
      progressPercent: progressPercent,
      isPrivate: isPrivate,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([post, ...current]);
  }

  Future<void> toggleLike(int postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.map((p) {
        if (p.id != postId) return p;
        final liked = !p.likedByMe;
        return p.copyWith(likedByMe: liked, likesCount: p.likesCount + (liked ? 1 : -1));
      }).toList(),
    );
    try {
      await _repo.toggleLike(postId);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> deletePost(int postId) async {
    await _repo.deletePost(postId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((p) => p.id != postId).toList());
  }

  @override
  void dispose() {
    _stopSSE();
    super.dispose();
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<Post>>>((ref) {
  return FeedNotifier(ref.read(postRepositoryProvider));
});

// Comments for a specific post (kept for CommentsScreen)
final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, postId) {
  return ref.read(postRepositoryProvider).getComments(postId);
});
