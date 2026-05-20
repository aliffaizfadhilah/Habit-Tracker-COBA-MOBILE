import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../habit/domain/habit_model.dart';
import '../../../habit/presentation/providers/habit_provider.dart';

class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Pengingat',
            style: GoogleFonts.syne(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ]),
      ),
      body: habitsAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => ErrorWidget2(
          message: 'Gagal memuat habit',
          onRetry: () => ref.read(habitListProvider.notifier).load(),
        ),
        data: (allHabits) {
          // Hide complete/locked habits from reminder list
          final habits = allHabits.where((h) => !h.isComplete).toList();

          if (allHabits.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.notifications_none_rounded,
                    size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text('Belum ada habit',
                  style: GoogleFonts.syne(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('Tambah habit terlebih dahulu untuk mengatur pengingat.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                  textAlign: TextAlign.center),
              ]),
            );
          }

          final active   = habits.where((h) => h.reminderEnabled).toList();
          final inactive = habits.where((h) => !h.reminderEnabled).toList();
          final total    = habits.length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(habitListProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Summary cards ────────────────────────────────────────────
                Row(children: [
                  _SummaryCard(
                    icon: Icons.notifications_rounded,
                    iconBg: AppColors.primaryLighter,
                    iconColor: AppColors.primary,
                    value: '$total',
                    label: 'Total Reminder',
                  ),
                  const SizedBox(width: 10),
                  _SummaryCard(
                    icon: Icons.check_circle_rounded,
                    iconBg: const Color(0xFFd1fae5),
                    iconColor: AppColors.primary,
                    value: '${active.length}',
                    label: 'Aktif',
                  ),
                  const SizedBox(width: 10),
                  _SummaryCard(
                    icon: Icons.pause_circle_rounded,
                    iconBg: const Color(0xFFf3f4f6),
                    iconColor: AppColors.muted,
                    value: '${inactive.length}',
                    label: 'Nonaktif',
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Info banner ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pengingat dikirim via push notification setiap hari pada waktu yang ditentukan.',
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.primaryMid),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Active reminders ─────────────────────────────────────────
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    title: 'Pengingat Aktif',
                    count: active.length,
                  ),
                  const SizedBox(height: 8),
                  ...active.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReminderCard(habit: h, ref: ref),
                  )),
                  const SizedBox(height: 16),
                ],

                // ── Inactive reminders ───────────────────────────────────────
                if (inactive.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.notifications_off_rounded,
                    color: AppColors.subtle,
                    title: 'Pengingat Nonaktif',
                    count: inactive.length,
                  ),
                  const SizedBox(height: 8),
                  ...inactive.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReminderCard(habit: h, ref: ref),
                  )),
                ],

                // ── Hidden-because-complete note ─────────────────────────────
                if (allHabits.any((h) => h.isComplete)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lock_rounded, size: 14, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${allHabits.where((h) => h.isComplete).length} habit sudah selesai dan pengingat otomatis dinonaktifkan.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _SummaryCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.value, required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: cardDecoration(radius: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                  style: GoogleFonts.syne(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                Text(label,
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      );
}

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon, required this.color,
    required this.title, required this.count,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
          style: GoogleFonts.syne(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]);
}

// ── Reminder Card ──────────────────────────────────────────────────────────────
class _ReminderCard extends StatelessWidget {
  final Habit habit;
  final WidgetRef ref;

  const _ReminderCard({required this.habit, required this.ref});

  Future<void> _toggleReminder(BuildContext context) async {
    await ref.read(habitListProvider.notifier).updateReminder(
      habit.idHabit,
      time: habit.reminderTime,
      enabled: !habit.reminderEnabled,
    );
  }

  Future<void> _editTime(BuildContext context) async {
    final parts = habit.reminderTime?.split(':') ?? ['07', '00'];
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await ref.read(habitListProvider.notifier).updateReminder(
        habit.idHabit,
        time: timeStr,
        enabled: habit.reminderEnabled,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active      = habit.reminderEnabled;
    final timeDisplay = habit.reminderTime ?? '--:--';

    return Opacity(
      opacity: active ? 1.0 : 0.65,
      child: Container(
        decoration: cardDecoration(radius: 14),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // ── Clock icon ────────────────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryLighter : const Color(0xFFf3f4f6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.access_time_rounded,
              size: 22, color: active ? AppColors.primary : AppColors.muted),
          ),
          const SizedBox(width: 12),

          // ── Info ──────────────────────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                habit.title,
                style: GoogleFonts.syne(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Time + category chip in a row — chip is Flexible to avoid overflow
              Row(children: [
                Text(
                  timeDisplay,
                  style: GoogleFonts.syne(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: active ? AppColors.primary : AppColors.muted),
                ),
                const SizedBox(width: 8),
                Flexible(child: _CategoryChip(habit.categoryDisplay)),
              ]),
              const SizedBox(height: 2),
              Text(
                active ? 'Setiap hari pukul $timeDisplay' : 'Pengingat dinonaktifkan',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.subtle),
              ),
            ]),
          ),

          // ── Controls ──────────────────────────────────────────────────────
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryLight : const Color(0xFFf3f4f6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'Aktif' : 'Nonaktif',
                  style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.muted),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // Edit button
                GestureDetector(
                  onTap: () => _editTime(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle switch
                GestureDetector(
                  onTap: () => _toggleReminder(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 24,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : const Color(0xFFd1d5db),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 18, height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Category Chip ──────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip(this.label);

  static const _colors = <String, Color>{
    'Kesehatan':        Color(0xFFf97316),
    'Ilmu Pengetahuan': Color(0xFF10b981),
    'Spiritual':        Color(0xFF6366f1),
    'Finansial':        Color(0xFF0ea5e9),
    'Personal':         Color(0xFFec4899),
    'Mental':           Color(0xFF16a34a),
    'Produktivitas':    Color(0xFF7c3aed),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[label] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w600, color: c),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
