import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/habit_model.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(dio: ref.read(dioProvider));
});

class HabitRepository {
  final Dio dio;
  HabitRepository({required this.dio});

  // Ambil semua habit (dengan streak data lengkap via /streak endpoint)
  Future<List<Habit>> getHabits() async {
    final res = await dio.get(ApiConstants.streak);
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => Habit.fromJson(e)).toList();
  }

  Future<Habit> createHabit({
    required String title,
    required String category,
    required String periodeStart,
    required String periodeEnd,
    required String reminderTime,
  }) async {
    final res = await dio.post(ApiConstants.habits, data: {
      'title': title,
      'category': category,
      'periode_start': periodeStart,
      'periode_end': periodeEnd,
      'reminder_time': reminderTime,
    });
    return Habit.fromJson(res.data['data'] ?? res.data);
  }

  Future<Habit> updateHabit(int idHabit, {
    required String title,
    required String category,
    required String periodeStart,
    required String periodeEnd,
    required String reminderTime,
  }) async {
    final res = await dio.put('${ApiConstants.habits}/$idHabit', data: {
      'title': title,
      'category': category,
      'periode_start': periodeStart,
      'periode_end': periodeEnd,
      'reminder_time': reminderTime,
    });
    return Habit.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> deleteHabit(int idHabit) async {
    await dio.delete('${ApiConstants.habits}/$idHabit');
  }

  Future<void> checkToday(int idHabit) async {
    await dio.post('${ApiConstants.habits}/$idHabit/check-today');
  }

  Future<void> updateReminder(int idHabit, {String? time, required bool enabled}) async {
    await dio.patch('${ApiConstants.habits}/$idHabit/reminder', data: {
      'reminder_time': time,
      'reminder_enabled': enabled,
    });
  }

  Future<List<String>> getCheckedDates(int idHabit) async {
    final res = await dio.get('${ApiConstants.habits}/$idHabit/checklist');
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => e.toString()).toList();
  }
}
