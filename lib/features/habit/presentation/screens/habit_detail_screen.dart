import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_model.dart';
import '../providers/habit_provider.dart';
import '../widgets/snapshot_sheet.dart';
import '../../../post/presentation/screens/post_form_screen.dart';

// Provider untuk checked dates per habit
final _checkedDatesProvider = FutureProvider.family<List<String>, int>((ref, idHabit) {
  return ref.read(habitRepositoryProvider).getCheckedDates(idHabit);
});

const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

enum _DayStatus { done, missed, future, todayDone, todayPending }

class HabitDetailScreen extends ConsumerWidget {
  final int idHabit;
  const HabitDetailScreen({super.key, required this.idHabit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final habit = habitsAsync.valueOrNull?.firstWhere(
      (h) => h.idHabit == idHabit,
      orElse: () => _placeholder,
    );

    if (habit == null || habit.idHabit == 0) {
      return const Scaffold(body: LoadingWidget());
    }

    return _HabitDetailView(habit: habit);
  }

  static final _placeholder = Habit(
    idHabit: 0, title: '', category: '',
    currentStreak: 0, longestStreak: 0,
    progressPercent: 0, totalPeriodDays: 0,
    totalCompletedDays: 0, reminderEnabled: false,
    checkedToday: false,
  );
}

class _HabitDetailView extends ConsumerWidget {
  final Habit habit;
  const _HabitDetailView({required this.habit});

  Future<void> _openSnapshot(BuildContext context) async {
    final result = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnapshotSheet(habit: habit),
    );
    // If user tapped "Post ke Feed", open PostFormSheet with snapshot pre-loaded
    if (result != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PostFormSheet(initialImage: result),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(_checkedDatesProvider(habit.idHabit));
    final isComplete = habit.isComplete;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(habit.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (isComplete)
            Container(
              margin: const EdgeInsets.only(left: 0, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Selesai 🎉',
                style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryMid),
              ),
            ),
          IconButton(
            onPressed: () => _openSnapshot(context),
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Share Progress',
            color: AppColors.primary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              decoration: cardDecoration(radius: 16),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _CategoryBadge(habit.category),
                    const SizedBox(width: 6),
                    if (isComplete) _StatusBadge('Selesai', AppColors.primaryMid, AppColors.successBg),
                    if (!isComplete && habit.checkedToday) _StatusBadge('Hari Ini ✓', AppColors.primaryMid, AppColors.successBg),
                  ]),
                  if (habit.periodeStart != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${habit.periodeStart} s/d ${habit.periodeEnd}',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats 4 kotak
            datesAsync.when(
              loading: () => const SizedBox(height: 80, child: LoadingWidget()),
              error: (_, __) => const SizedBox.shrink(),
              data: (checkedDates) {
                final today = DateTime.now().toIso8601String().substring(0, 10);
                final checkedSet = checkedDates.toSet();
                final allDates = _generateDates(habit.periodeStart, habit.periodeEnd);
                final doneDays = allDates.where((d) => checkedSet.contains(d)).length;
                final missedDays = allDates.where((d) => d.compareTo(today) < 0 && !checkedSet.contains(d)).length;

                return Column(
                  children: [
                    // 4 stat boxes
                    Row(children: [
                      Expanded(child: _StatBox(
                        icon: Icons.trending_up_rounded, color: AppColors.primary,
                        label: 'Progress', value: '${habit.progressPercent.toStringAsFixed(0)}%',
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _StatBox(
                        icon: Icons.check_circle_rounded, color: AppColors.primary,
                        label: 'Selesai', value: '$doneDays hari',
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _StatBox(
                        icon: Icons.cancel_rounded, color: AppColors.error,
                        label: 'Terlewat', value: '$missedDays hari',
                        valueColor: AppColors.error,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _StatBox(
                        icon: Icons.emoji_events_rounded, color: const Color(0xFFf97316),
                        label: 'Streak', value: '${habit.currentStreak}',
                        valueColor: const Color(0xFFf97316),
                      )),
                    ]),
                    const SizedBox(height: 12),

                    // Progress bar
                    Container(
                      decoration: cardDecoration(radius: 14),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress (${habit.totalCompletedDays}/${habit.totalPeriodDays} hari)',
                                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                              ),
                              Text(
                                '${habit.progressPercent.toStringAsFixed(0)}%',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: isComplete ? AppColors.primary : AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (habit.progressPercent / 100).clamp(0, 1),
                              backgroundColor: AppColors.primaryLight,
                              valueColor: AlwaysStoppedAnimation(
                                isComplete ? AppColors.primary : AppColors.accent,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calendar grid
                    Container(
                      decoration: cardDecoration(radius: 14),
                      padding: const EdgeInsets.all(16),
                      child: _CalendarGrid(
                        allDates: allDates,
                        checkedDates: checkedSet,
                        today: today,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Streak info
                    Container(
                      decoration: cardDecoration(radius: 14),
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.emoji_events_rounded, size: 18, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Longest streak: ${habit.longestStreak} hari berturut-turut',
                              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                            ),
                            Text(
                              'Current streak: ${habit.currentStreak} hari',
                              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _generateDates(String? start, String? end) {
    if (start == null || end == null) return [];
    final dates = <String>[];
    var d = DateTime.parse(start);
    final endDate = DateTime.parse(end);
    while (!d.isAfter(endDate)) {
      dates.add(d.toIso8601String().substring(0, 10));
      d = d.add(const Duration(days: 1));
    }
    return dates;
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<String> allDates;
  final Set<String> checkedDates;
  final String today;

  const _CalendarGrid({
    required this.allDates,
    required this.checkedDates,
    required this.today,
  });

  int _colIndex(String dateStr) {
    return (DateTime.parse(dateStr).weekday - 1) % 7; // 0=Sen, 6=Min
  }

  List<List<String?>> _groupWeeks() {
    if (allDates.isEmpty) return [];
    final weeks = <List<String?>>[];
    var week = List<String?>.filled(_colIndex(allDates.first), null, growable: true);
    for (final d in allDates) {
      week.add(d);
      if (week.length == 7) {
        weeks.add(week);
        week = [];
      }
    }
    if (week.isNotEmpty) {
      while (week.length < 7) week.add(null);
      weeks.add(week);
    }
    return weeks;
  }

  _DayStatus _dayStatus(String d) {
    if (d == today) return checkedDates.contains(d) ? _DayStatus.todayDone : _DayStatus.todayPending;
    if (checkedDates.contains(d)) return _DayStatus.done;
    if (d.compareTo(today) < 0) return _DayStatus.missed;
    return _DayStatus.future;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _groupWeeks();
    if (weeks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Hari-hari',
          style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 10),

        // Legend
        Wrap(
          spacing: 12, runSpacing: 6,
          children: [
            _Legend(color: const Color(0xFF16a34a), label: '✓ Selesai'),
            _Legend(color: AppColors.error, label: '✗ Terlewat'),
            _Legend(color: const Color(0xFFf3f4f6), label: '· Belum'),
            _Legend(color: const Color(0xFFfff7ed), label: '! Hari ini'),
          ],
        ),
        const SizedBox(height: 10),

        // Day labels row
        Row(
          children: _dayLabels.map((l) => Expanded(
            child: Center(
              child: Text(l,
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),

        // Calendar weeks
        ...weeks.map((week) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: week.map((d) {
              if (d == null) return const Expanded(child: SizedBox());
              final status = _dayStatus(d);
              final (bg, color, label, border) = _style(status, d == today);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 36,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border, width: border == Colors.transparent ? 0 : 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateTime.parse(d).day.toString(),
                        style: GoogleFonts.dmSans(fontSize: 9, color: color.withOpacity(0.7)),
                      ),
                      Text(label,
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        )),
      ],
    );
  }

  (Color bg, Color color, String label, Color border) _style(_DayStatus s, bool isToday) {
    return switch (s) {
      _DayStatus.done => (const Color(0xFFdcfce7), const Color(0xFF16a34a), '✓', Colors.transparent),
      _DayStatus.missed => (const Color(0xFFfee2e2), AppColors.error, '✗', Colors.transparent),
      _DayStatus.future => (const Color(0xFFf3f4f6), AppColors.subtle, '·', Colors.transparent),
      _DayStatus.todayDone => (const Color(0xFF16a34a), Colors.white, '✓', Colors.transparent),
      _DayStatus.todayPending => (const Color(0xFFfff7ed), const Color(0xFFea580c), '!', const Color(0xFF16a34a)),
    };
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
        ],
      );
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatBox({
    required this.icon, required this.color,
    required this.label, required this.value, this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.primary),
            ),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      );
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge(this.category);

  static const _colors = {
    'Kesehatan': Color(0xFFf97316),
    'Ilmu Pengetahuan': Color(0xFF10b981),
    'Mental': Color(0xFF16a34a),
    'Produktivitas': Color(0xFF7c3aed),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[category] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(category, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusBadge(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}
