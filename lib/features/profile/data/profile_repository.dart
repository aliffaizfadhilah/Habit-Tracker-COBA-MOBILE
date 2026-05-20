import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../post/domain/post_model.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(dio: ref.read(dioProvider));
});

class ProfileRepository {
  final Dio dio;
  ProfileRepository({required this.dio});

  Future<UserProfile> getProfile() async {
    try {
      final res = await dio.get(ApiConstants.profile);
      return UserProfile.fromJson(res.data);
    } catch (e, st) {
      debugPrint('[Profile] getProfile error: $e\n$st');
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required String username,
    required String email,
  }) async {
    final res = await dio.put(ApiConstants.profile, data: {
      'full_name': fullName,
      'username': username,
      'email': email,
    });
    return UserProfile.fromJson(res.data);
  }

  Future<List<Post>> getMyPosts() async {
    try {
      final res = await dio.get(ApiConstants.posts, queryParameters: {'mine': 1});
      final data = res.data['data'] as List? ?? [];
      return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, st) {
      debugPrint('[Profile] getMyPosts error: $e\n$st');
      rethrow;
    }
  }

  Future<void> requestChangePasswordOtp() async {
    await dio.post(ApiConstants.changePasswordRequest);
  }

  Future<void> verifyChangePasswordOtp(String otp) async {
    await dio.post(ApiConstants.changePasswordVerify, data: {'otp': otp});
  }

  Future<void> changePassword({
    required String otp,
    required String newPassword,
    required String confirmation,
  }) async {
    await dio.post(ApiConstants.changePassword, data: {
      'otp': otp,
      'password': newPassword,
      'password_confirmation': confirmation,
    });
  }
}
