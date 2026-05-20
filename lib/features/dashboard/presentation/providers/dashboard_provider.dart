import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/streak_model.dart';

final dashboardProvider = FutureProvider<StreakSummary>((ref) {
  return ref.read(dashboardRepositoryProvider).getSummary();
});

final activityLogsProvider = FutureProvider<List<ActivityLog>>((ref) {
  return ref.read(dashboardRepositoryProvider).getActivityLogs();
});
