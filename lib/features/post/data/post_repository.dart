import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/post_model.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(dio: ref.read(dioProvider));
});

class PostRepository {
  final Dio dio;
  PostRepository({required this.dio});

  Future<List<Post>> getPosts() async {
    try {
      final res = await dio.get(ApiConstants.posts);
      final data = res.data['data'] as List? ?? res.data as List;
      return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, st) {
      debugPrint('[Feed] getPosts error: $e\n$st');
      rethrow;
    }
  }

  Future<Post> createPost({
    required String title,
    String? caption,
    required String imagePath,
    String frameStyle = 'rect',
    int? habitId,
    String? habitTitle,
    double? progressPercent,
    bool isPrivate = false,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'image': await MultipartFile.fromFile(imagePath),
      'frame_style': frameStyle,
      'is_private': isPrivate ? '1' : '0',
      if (habitId != null) 'habit_id': habitId,
      if (habitTitle != null) 'habit_title': habitTitle,
      if (progressPercent != null) 'progress_percent': progressPercent,
    });
    final res = await dio.post(ApiConstants.posts, data: formData);
    final raw = res.data['data'] ?? res.data;
    return Post.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> deletePost(int id) async {
    await dio.delete('${ApiConstants.posts}/$id');
  }

  Future<void> toggleLike(int postId) async {
    await dio.post('${ApiConstants.posts}/$postId/like');
  }

  Future<List<Comment>> getComments(int postId) async {
    final res = await dio.get('${ApiConstants.posts}/$postId/comments');
    final data = res.data['data'] as List? ?? res.data as List;
    return data.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Comment> addComment(int postId, String content) async {
    final res = await dio.post(
      '${ApiConstants.posts}/$postId/comments',
      data: {'content': content},
    );
    final raw = res.data['data'] ?? res.data;
    return Comment.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> deleteComment(int postId, int commentId) async {
    await dio.delete('${ApiConstants.posts}/$postId/comments/$commentId');
  }
}
