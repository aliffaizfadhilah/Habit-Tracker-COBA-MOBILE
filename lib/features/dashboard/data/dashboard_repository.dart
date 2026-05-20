import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/streak_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(dio: ref.read(dioProvider));
});

class DashboardRepository {
  final Dio dio;
  DashboardRepository({required this.dio});

  // Pakai /streak (bukan /streak/summary) agar dapat checked_today per habit
  Future<StreakSummary> getSummary() async {
    final res = await dio.get(ApiConstants.streak);
    return StreakSummary.fromJson(res.data);
  }

  Future<List<ActivityLog>> getActivityLogs() async {
    final res = await dio.get(ApiConstants.activityLogs);
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => ActivityLog.fromJson(e as Map<String, dynamic>)).toList();
  }
}
