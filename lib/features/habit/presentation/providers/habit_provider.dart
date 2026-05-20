import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_model.dart';
import '../../../../core/network/sse_client.dart';
import '../../../../core/constants/api_constants.dart';

class HabitListNotifier extends StateNotifier<AsyncValue<List<Habit>>>
    with WidgetsBindingObserver {
  final HabitRepository _repo;
  SseClient? _sseClient;
  Timer? _fallbackTimer;

  HabitListNotifier(this._repo) : super(const AsyncValue.loading()) {
    WidgetsBinding.instance.addObserver(this);
    load();
    _startSSE();
  }

  // ── Lifecycle: pause SSE when app goes to background ──────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      _startSSE();
    } else if (state == AppLifecycleState.paused) {
      _stopSSE();
    }
  }

  void _startSSE() {
    _stopSSE();
    _sseClient = SseClient(
      dio: _repo.dio,
      path: ApiConstants.habitsStream,
      onEvent: (event, _) {
        if (event == 'habits_updated' && mounted) _silentRefresh();
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
        delay = 2; // reset backoff after successful connection
      } on DioException catch (e) {
        if (!mounted || e.type == DioExceptionType.cancel) break;
        // Start fallback polling while waiting to reconnect
        _fallbackTimer ??= Timer.periodic(
          const Duration(seconds: 15),
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

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    try {
      final habits = await _repo.getHabits();
      if (mounted) state = AsyncValue.data(habits);
    } catch (_) {
      // Diam saja saat refresh gagal — jangan reset state
    }
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getHabits);
  }

  Future<void> toggleCheck(int idHabit) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic update
    state = AsyncValue.data(
      current.map((h) => h.idHabit == idHabit
          ? h.copyWith(checkedToday: !h.checkedToday)
          : h).toList(),
    );

    try {
      await _repo.checkToday(idHabit);
      await _silentRefresh();
    } catch (_) {
      state = AsyncValue.data(current); // revert on error
    }
  }

  Future<void> addHabit({
    required String title,
    required String category,
    required String periodeStart,
    required String periodeEnd,
    required String reminderTime,
  }) async {
    await _repo.createHabit(
      title: title,
      category: category,
      periodeStart: periodeStart,
      periodeEnd: periodeEnd,
      reminderTime: reminderTime,
    );
    await load();
  }

  Future<void> editHabit(int idHabit, {
    required String title,
    required String category,
    required String periodeStart,
    required String periodeEnd,
    required String reminderTime,
  }) async {
    await _repo.updateHabit(
      idHabit,
      title: title,
      category: category,
      periodeStart: periodeStart,
      periodeEnd: periodeEnd,
      reminderTime: reminderTime,
    );
    await load();
  }

  Future<void> deleteHabit(int idHabit) async {
    await _repo.deleteHabit(idHabit);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((h) => h.idHabit != idHabit).toList());
  }

  Future<void> updateReminder(int idHabit, {String? time, required bool enabled}) async {
    await _repo.updateReminder(idHabit, time: time, enabled: enabled);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((h) => h.idHabit == idHabit
          ? h.copyWith(reminderEnabled: enabled, reminderTime: time)
          : h).toList(),
    );
  }

  @override
  void dispose() {
    _stopSSE();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final habitListProvider = StateNotifierProvider<HabitListNotifier, AsyncValue<List<Habit>>>((ref) {
  return HabitListNotifier(ref.read(habitRepositoryProvider));
});
