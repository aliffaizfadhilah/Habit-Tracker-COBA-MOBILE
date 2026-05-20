import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../habit/presentation/providers/habit_provider.dart';
import '../../../habit/domain/habit_model.dart';

class RiwayatScreen extends ConsumerWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now());
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Riwayat'),
            Text(
              dateStr,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: habitsAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => ErrorWidget2(
          message: 'Gagal memuat riwayat',
          onRetry: () => ref.read(habitListProvider.notifier).load(),
        ),
        data: (habits) {
          final dikerjakanHariIni = habits.where((h) => h.checkedToday).toList();
          final reminderTerlewat = habits.where((h) {
            if (!h.reminderEnabled || h.reminderTime == null || h.checkedToday) return false;
            return h.reminderTime!.compareTo(currentTime) <= 0;
          }).toList();
          final habitSelesai = habits.where((h) => h.isComplete).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(habitListProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RiwayatSection(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Dikerjakan Hari Ini',
                  count: dikerjakanHariIni.length,
                  emptyMessage: 'Belum ada habit yang dikerjakan hari ini.',
                  items: dikerjakanHariIni.map((h) => _RiwayatItem(
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.primary,
                    bg: const Color(0xFFf0fdf4),
                    border: const Color(0xFFbbf7d0),
                    title: h.title,
                    subtitle: h.categoryDisplay,
                    trailing: '${h.progressPercent.toStringAsFixed(0)}%',
                    trailingColor: AppColors.primary,
                  )).toList(),
                ),
                const SizedBox(height: 20),

                _RiwayatSection(
                  icon: Icons.notifications_off_outlined,
                  iconColor: const Color(0xFFf97316),
                  title: 'Reminder Terlewat',
                  count: reminderTerlewat.length,
                  emptyMessage: 'Tidak ada reminder yang terlewat hari ini.',
                  items: reminderTerlewat.map((h) => _RiwayatItem(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFFf97316),
                    bg: const Color(0xFFfff7ed),
                    border: const Color(0xFFfed7aa),
                    title: h.title,
                    subtitle: 'Pengingat pukul ${h.reminderTime}',
                    trailing: 'Belum dikerjakan',
                    trailingColor: const Color(0xFFf97316),
                  )).toList(),
                ),
                const SizedBox(height: 20),

                _RiwayatSection(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.accent,
                  title: 'Habit Selesai',
                  count: habitSelesai.length,
                  emptyMessage: 'Belum ada habit yang selesai 100%.',
                  items: habitSelesai.map((h) => _RiwayatItem(
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.accent,
                    bg: const Color(0xFFf0fdf4),
                    border: const Color(0xFFbbf7d0),
                    title: h.title,
                    subtitle: '${h.periodeStart} s/d ${h.periodeEnd}',
                    trailing: '100%',
                    trailingColor: AppColors.accent,
                  )).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RiwayatSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final String emptyMessage;
  final List<Widget> items;

  const _RiwayatSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.emptyMessage,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        if (items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(emptyMessage, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
            ),
          )
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: item,
              )),
      ],
    );
  }
}

class _RiwayatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final Color border;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;

  const _RiwayatItem({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                overflow: TextOverflow.ellipsis),
              Text(subtitle,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        Text(trailing,
          style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w700, color: trailingColor)),
      ]),
    );
  }
}
