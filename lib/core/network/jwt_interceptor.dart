import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class JwtInterceptor extends Interceptor {
  final SecureStorage storage;
  final Dio dio;

  JwtInterceptor({required this.storage, required this.dio});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      storage.clearToken();
    }
    handler.next(err);
  }
}
