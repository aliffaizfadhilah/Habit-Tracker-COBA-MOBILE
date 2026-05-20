import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/auth_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.read(dioProvider),
    storage: ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio dio;
  final SecureStorage storage;

  AuthRepository({required this.dio, required this.storage});

  Future<void> login(String email, String password) async {
    try {
      final res = await dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      debugPrint('[Auth] login response: ${res.data}');
      final token = res.data['token'] as String?;
      if (token == null) throw Exception('Token tidak ditemukan di response');
      await storage.saveToken(token);
    } on DioException catch (e) {
      debugPrint('[Auth] login DioException: ${e.type} | status: ${e.response?.statusCode} | data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[Auth] login error: $e');
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await dio.post(ApiConstants.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<void> logout() async {
    try {
      await dio.post(ApiConstants.logout);
    } finally {
      await storage.clearToken();
    }
  }

  Future<void> forgotPassword(String email) async {
    await dio.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  Future<void> verifyForgotOtp(String email, String otp) async {
    await dio.post(ApiConstants.verifyForgotOtp, data: {
      'email': email,
      'otp': otp,
    });
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    await dio.post(ApiConstants.resetPassword, data: {
      'email': email,
      'otp': otp,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<AuthUser> me() async {
    final res = await dio.get(ApiConstants.me);
    return AuthUser.fromJson(res.data['user'] ?? res.data);
  }
}
