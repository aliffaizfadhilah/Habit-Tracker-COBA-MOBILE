import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/habit_model.dart';

Color _categoryColor(String cat) {
  switch (cat.toLowerCase().replaceAll(' ', '_')) {
    case 'kesehatan':        return const Color(0xFFf97316);
    case 'ilmu_pengetahuan': return const Color(0xFF10b981);
    case 'spiritual':        return const Color(0xFF6366f1);
    case 'finansial':        return const Color(0xFF0ea5e9);
    case 'personal':         return const Color(0xFFec4899);
    case 'lainnya':          return const Color(0xFF8b5cf6);
    // legacy
    case 'mental':           return const Color(0xFF16a34a);
    case 'produktivitas':    return const Color(0xFF7c3aed);
    default: return AppColors.primary;
  }
}

class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDetail;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final done = habit.checkedToday;
    final complete = habit.isComplete;
    final catColor = _categoryColor(habit.category);
    final progress = habit.progressPercent.clamp(0, 100) / 100;

    return GestureDetector(
      onTap: onDetail,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: complete ? AppColors.borderMid : (done ? AppColors.borderMid : AppColors.border),
            width: complete ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: complete
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: complete ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top accent bar for complete habits
            if (complete)
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Check button
                      GestureDetector(
                        onTap: complete ? null : onToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: done ? AppColors.primary : AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: done ? AppColors.primary : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: complete
                              ? const Icon(Icons.lock_rounded, size: 16, color: AppColors.border)
                              : done
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                  : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + badges
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    habit.title,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Category + badges row
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _Chip(label: habit.categoryDisplay, color: catColor, bg: catColor.withOpacity(0.1)),
                                if (complete)
                                  _Chip(label: 'Selesai', color: AppColors.primaryMid, bg: AppColors.successBg),
                                if (!complete && done)
                                  _Chip(label: 'Hari Ini ✓', color: AppColors.primaryMid, bg: AppColors.successBg),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Period dates
                            if (habit.periodeStart != null && habit.periodeEnd != null)
                              Text(
                                '${habit.periodeStart} s/d ${habit.periodeEnd}',
                                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.subtle),
                              ),
                          ],
                        ),
                      ),

                      // Streak + menu
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.subtle, size: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit') onEdit();
                              if (v == 'delete') onDelete();
                              if (v == 'detail') onDetail?.call();
                            },
                            itemBuilder: (_) => [
                              if (onDetail != null)
                                PopupMenuItem(
                                  value: 'detail',
                                  child: _PopMenuItem(Icons.bar_chart_rounded, 'Lihat detail', AppColors.ink),
                                ),
                              PopupMenuItem(
                                value: 'edit',
                                child: _PopMenuItem(Icons.edit_outlined, 'Edit', AppColors.ink),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: _PopMenuItem(Icons.delete_outline_rounded, 'Hapus', AppColors.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFf97316)),
                              const SizedBox(width: 2),
                              Text(
                                '${habit.currentStreak}',
                                style: GoogleFonts.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFf97316),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'streak',
                            style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.subtle),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress (${habit.totalCompletedDays}/${habit.totalPeriodDays} hari)',
                                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                                ),
                                Text(
                                  '${habit.progressPercent.toStringAsFixed(0)}%',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: complete ? AppColors.primary : AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.toDouble(),
                                backgroundColor: AppColors.primaryLight,
                                valueColor: AlwaysStoppedAnimation(
                                  complete ? AppColors.primary : catColor,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Lock notice for completed habits
                  if (complete) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Habit ini sudah selesai dan tidak dapat diubah lagi.',
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Longest streak
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 12, color: Color(0xFF10b981)),
                      const SizedBox(width: 4),
                      Text(
                        'Longest streak: ',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                      ),
                      Text(
                        '${habit.longestStreak} hari',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

class _PopMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PopMenuItem(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.dmSans(color: color)),
      ]);
}
