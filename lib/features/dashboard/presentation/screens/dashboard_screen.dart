import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../habit/presentation/providers/habit_provider.dart';
import '../../../habit/domain/habit_model.dart';
import '../../../habit/presentation/widgets/habit_card.dart';
import '../../../habit/presentation/screens/habit_form_screen.dart';
import '../../domain/streak_model.dart';
import '../providers/dashboard_provider.dart';

typedef _Filter = String;
const _fSemua = 'semua';
const _fHariIni = 'selesai_hari_ini';
const _fSelesai = 'selesai';
const _fBelum = 'belum_selesai';

// ── Day abbreviation helper (Dart weekday: 1=Mon…7=Sun) ──────────────────────
String _dayName(DateTime d) {
  const names = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  return names[d.weekday];
}

// ── Weekly bar computation ────────────────────────────────────────────────────
List<WeeklyBar> _computeWeekly(List<ActivityLog> logs) {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    final dateStr = DateFormat('yyyy-MM-dd').format(d);
    return WeeklyBar(
      day: _dayName(d),
      val: logs.where((l) => l.date == dateStr && l.status == 1).length,
      isToday: i == 6,
    );
  });
}

// ── Insight model ─────────────────────────────────────────────────────────────
class _DashInsight {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String title;
  final String sub;
  const _DashInsight({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.title,
    required this.sub,
  });
}

// ── At-risk model ─────────────────────────────────────────────────────────────
class _AtRisk {
  final String name;
  final String label;
  final String level; // 'high' | 'mid' | 'ok'
  const _AtRisk({required this.name, required this.label, required this.level});
}

// ── Insights computation ──────────────────────────────────────────────────────
List<_DashInsight> _computeInsights(List<Habit> habits, List<ActivityLog> logs) {
  if (habits.isEmpty) return [];

  final now = DateTime.now();
  final cutoff = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
  final today = DateFormat('yyyy-MM-dd').format(now);

  final thisWeek = logs.where((l) => l.date.compareTo(cutoff) >= 0 && l.status == 1).toList();

  final byHabit = <int, int>{};
  final byDay = <String, int>{};
  for (final l in thisWeek) {
    byHabit[l.idHabit] = (byHabit[l.idHabit] ?? 0) + 1;
    final d = DateTime.parse('${l.date}T00:00:00');
    byDay[_dayName(d)] = (byDay[_dayName(d)] ?? 0) + 1;
  }

  MapEntry<int, int>? bestHabitEntry;
  for (final e in byHabit.entries) {
    if (bestHabitEntry == null || e.value > bestHabitEntry.value) bestHabitEntry = e;
  }
  final bestHabit = bestHabitEntry != null
      ? habits.where((h) => h.idHabit == bestHabitEntry!.key).cast<Habit?>().firstOrNull
      : null;
  final bestCount = bestHabitEntry?.value ?? 0;

  MapEntry<String, int>? bestDayEntry;
  for (final e in byDay.entries) {
    if (bestDayEntry == null || e.value > bestDayEntry.value) bestDayEntry = e;
  }

  final notDone = habits
      .where((h) => h.progressPercent < 100 && (h.periodeEnd ?? '').compareTo(today) >= 0)
      .toList()
    ..sort((a, b) => a.progressPercent.compareTo(b.progressPercent));
  final atRiskHabit = notDone.isNotEmpty ? notDone.first : null;

  final completedFull = habits.where((h) => h.progressPercent >= 100).length;
  final avgProgress = habits.fold(0.0, (s, h) => s + h.progressPercent) / habits.length;

  final result = <_DashInsight>[];

  if (bestHabit != null && bestCount > 0) {
    result.add(_DashInsight(
      icon: Icons.local_fire_department_rounded,
      iconColor: const Color(0xFFf97316),
      bg: const Color(0xFFfff7ed),
      title: '${bestHabit.title} paling konsisten minggu ini',
      sub: '$bestCount/7 hari selesai — pertahankan!',
    ));
  }

  result.add(_DashInsight(
    icon: Icons.trending_up_rounded,
    iconColor: const Color(0xFF16a34a),
    bg: const Color(0xFFf0fdf4),
    title: 'Rata-rata progress ${avgProgress.toStringAsFixed(0)}%',
    sub: completedFull > 0
        ? '$completedFull habit sudah selesai 100%!'
        : 'Terus tingkatkan progressmu!',
  ));

  if (bestDayEntry != null) {
    result.add(_DashInsight(
      icon: Icons.star_rounded,
      iconColor: const Color(0xFFf59e0b),
      bg: const Color(0xFFeef1ff),
      title: '${bestDayEntry.key} paling produktif minggu ini',
      sub: '${bestDayEntry.value} habit selesai hari ${bestDayEntry.key}',
    ));
  }

  if (atRiskHabit != null) {
    final weekCount = byHabit[atRiskHabit.idHabit] ?? 0;
    result.add(_DashInsight(
      icon: Icons.bolt_rounded,
      iconColor: const Color(0xFFef4444),
      bg: const Color(0xFFfef2f2),
      title: '${atRiskHabit.title} butuh perhatian',
      sub: '$weekCount/7 hari selesai, progress ${atRiskHabit.progressPercent.toStringAsFixed(0)}%',
    ));
  }

  return result;
}

// ── At-risk computation ───────────────────────────────────────────────────────
List<_AtRisk> _computeAtRisk(List<Habit> habits) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return habits
      .where((h) => h.progressPercent < 100 && (h.periodeEnd ?? '').compareTo(today) >= 0)
      .take(5)
      .map((h) {
        if (h.currentStreak == 0 && h.totalCompletedDays > 0) {
          return _AtRisk(name: h.title, label: 'Streak terputus', level: 'high');
        }
        if (!h.checkedToday && h.currentStreak <= 2) {
          return _AtRisk(name: h.title, label: 'Streak ${h.currentStreak} hari', level: 'mid');
        }
        return _AtRisk(name: h.title, label: 'On track ✓', level: 'ok');
      })
      .toList();
}

// ═══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _Filter _filter = _fSemua;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Habit>>>(habitListProvider, (_, next) {
      if (next.hasValue) {
        ref.invalidate(dashboardProvider);
        ref.invalidate(activityLogsProvider);
      }
    });
    final summaryAsync = ref.watch(dashboardProvider);
    final habitsAsync = ref.watch(habitListProvider);
    final logsAsync = ref.watch(activityLogsProvider);
    final user = ref.watch(currentUserProvider);

    final allHabits = habitsAsync.valueOrNull ?? [];
    final logs = logsAsync.valueOrNull ?? [];
    final filtered = _applyFilter(allHabits, _filter);
    final counts = _counts(allHabits);
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now());

    final weeklyData = _computeWeekly(logs);
    final insights = _computeInsights(allHabits, logs);
    final atRisk = _computeAtRisk(allHabits);
    final maxBar = weeklyData.fold(1, (m, d) => d.val > m ? d.val : m);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(activityLogsProvider);
          await ref.read(habitListProvider.notifier).load();
        },
        child: CustomScrollView(
          slivers: [
            // AppBar
            SliverAppBar(
              backgroundColor: AppColors.white,
              floating: true,
              snap: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text('Dashboard', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ]),
              actions: [
                TextButton.icon(
                  onPressed: () => context.push('/riwayat'),
                  icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.ink),
                  label: Text('Riwayat', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Greeting Banner ────────────────────────────────────
                  summaryAsync.when(
                    loading: () => const SizedBox(height: 100, child: LoadingWidget()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (s) => _GreetingBanner(
                      name: user?.name.split(' ').first ?? 'User',
                      streak: s.totalCurrentStreak,
                      checkedToday: s.checkedToday,
                      totalHabits: s.totalHabits,
                      avgProgress: s.avgProgress,
                      dateStr: dateStr,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stat Cards ─────────────────────────────────────────
                  summaryAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (s) => _StatsGrid(summary: s),
                  ),
                  const SizedBox(height: 16),

                  // ── Weekly Chart ───────────────────────────────────────
                  _WeeklyChart(weeklyData: weeklyData, maxBar: maxBar),
                  const SizedBox(height: 12),

                  // ── Insight Minggu Ini ─────────────────────────────────
                  if (insights.isNotEmpty) ...[
                    _InsightSection(insights: insights),
                    const SizedBox(height: 20),
                  ],

                  // ── Streak & Progress title ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Streak & Progress Habitmu',
                        style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${allHabits.length} habit',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Filter Tabs ────────────────────────────────────────
                  if (allHabits.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterTab(label: 'Semua', count: counts[_fSemua]!, active: _filter == _fSemua,
                              onTap: () => setState(() => _filter = _fSemua)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Selesai Hari Ini', count: counts[_fHariIni]!, active: _filter == _fHariIni,
                              onTap: () => setState(() => _filter = _fHariIni)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Selesai', count: counts[_fSelesai]!, active: _filter == _fSelesai,
                              onTap: () => setState(() => _filter = _fSelesai)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Belum Selesai', count: counts[_fBelum]!, active: _filter == _fBelum,
                              onTap: () => setState(() => _filter = _fBelum)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Habit List ─────────────────────────────────────────
                  habitsAsync.when(
                    loading: () => const LoadingWidget(),
                    error: (_, __) => ErrorWidget2(
                      message: 'Gagal memuat habit',
                      onRetry: () => ref.read(habitListProvider.notifier).load(),
                    ),
                    data: (_) {
                      if (allHabits.isEmpty) return _EmptyState(onAdd: () => _openForm(context, ref));
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Tidak ada habit di kategori ini',
                              style: GoogleFonts.dmSans(color: AppColors.muted),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: filtered.map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: HabitCard(
                            habit: h,
                            onToggle: () => ref.read(habitListProvider.notifier).toggleCheck(h.idHabit),
                            onEdit: () => _openForm(context, ref, habit: h),
                            onDelete: () => _confirmDelete(context, ref, h),
                            onDetail: () => context.push('/habit-detail/${h.idHabit}'),
                          ),
                        )).toList(),
                      );
                    },
                  ),

                  // ── Perlu Perhatian ────────────────────────────────────
                  if (atRisk.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _AtRiskSection(atRisk: atRisk),
                  ],

                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  List<Habit> _applyFilter(List<Habit> habits, _Filter f) {
    if (f == _fHariIni) return habits.where((h) => h.checkedToday).toList();
    if (f == _fSelesai) return habits.where((h) => h.isComplete).toList();
    if (f == _fBelum) return habits.where((h) => !h.isComplete).toList();
    return habits;
  }

  Map<_Filter, int> _counts(List<Habit> h) => {
        _fSemua: h.length,
        _fHariIni: h.where((x) => x.checkedToday).length,
        _fSelesai: h.where((x) => x.isComplete).length,
        _fBelum: h.where((x) => !x.isComplete).length,
      };

  void _openForm(BuildContext context, WidgetRef ref, {Habit? habit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitFormSheet(habit: habit, ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus habit?', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        content: Text('"${habit.title}" akan dihapus permanen.', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(habitListProvider.notifier).deleteHabit(habit.idHabit);
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Greeting Banner ────────────────────────────────────────────────────────────
class _GreetingBanner extends StatelessWidget {
  final String name;
  final int streak;
  final int checkedToday;
  final int totalHabits;
  final double avgProgress;
  final String dateStr;

  const _GreetingBanner({
    required this.name,
    required this.streak,
    required this.checkedToday,
    required this.totalHabits,
    required this.avgProgress,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16a34a), Color(0xFF10b981), Color(0xFF34d399)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: -40,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $name! 👋',
                style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                streak > 0
                    ? 'Kamu sudah $streak hari berturut-turut — terus pertahankan!'
                    : 'Semangat memulai hari ini!',
                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _BannerChip(Icons.local_fire_department_rounded, '$streak hari streak'),
                  _BannerChip(Icons.check_box_rounded, '$checkedToday/$totalHabits selesai hari ini'),
                  _BannerChip(Icons.trending_up_rounded, '${avgProgress.toStringAsFixed(0)}% avg progress'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BannerChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      );
}

// ── Stats Grid ─────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final StreakSummary summary;
  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'SELESAI HARI INI',
          value: '${summary.checkedToday}/${summary.totalHabits}',
          icon: Icons.check_box_rounded,
          iconBg: AppColors.primaryLighter,
          iconColor: AppColors.primary,
          barColor: AppColors.primary,
          barWidth: summary.totalHabits > 0 ? summary.checkedToday / summary.totalHabits : 0,
        ),
        _StatCard(
          label: 'TOTAL STREAK',
          value: '${summary.totalCurrentStreak} hari',
          icon: Icons.local_fire_department_rounded,
          iconBg: const Color(0xFFfff7ed),
          iconColor: const Color(0xFFf97316),
          barColor: const Color(0xFFf97316),
          barWidth: (summary.totalCurrentStreak / (summary.longestStreak.clamp(1, 999))).clamp(0, 1),
        ),
        _StatCard(
          label: 'REKOR TERBAIK',
          value: '${summary.longestStreak} hari',
          icon: Icons.emoji_events_rounded,
          iconBg: const Color(0xFFfffbeb),
          iconColor: const Color(0xFFf59e0b),
          barColor: const Color(0xFFf59e0b),
          barWidth: 1.0,
        ),
        _StatCard(
          label: 'AVG PROGRESS',
          value: '${summary.avgProgress.toStringAsFixed(0)}%',
          icon: Icons.trending_up_rounded,
          iconBg: AppColors.primaryLighter,
          iconColor: AppColors.accent,
          barColor: AppColors.accent,
          barWidth: summary.avgProgress / 100,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color barColor;
  final double barWidth;

  const _StatCard({
    required this.label, required this.value, required this.icon,
    required this.iconBg, required this.iconColor,
    required this.barColor, required this.barWidth,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis),
                ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
              ],
            ),
            const Spacer(),
            Text(value, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: barWidth.clamp(0, 1).toDouble(),
              backgroundColor: AppColors.primaryLighter,
              valueColor: AlwaysStoppedAnimation(barColor),
              borderRadius: BorderRadius.circular(2),
              minHeight: 3,
            ),
          ],
        ),
      );
}

// ── Weekly Chart ───────────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<WeeklyBar> weeklyData;
  final int maxBar;

  const _WeeklyChart({required this.weeklyData, required this.maxBar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Penyelesaian Mingguan',
                    style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text('Jumlah habit selesai per hari',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                child: Text('7 hari',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((d) {
                final frac = maxBar > 0 ? d.val / maxBar : 0.0;
                final barH = (frac * 70).clamp(4.0, 70.0);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${d.val}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: d.isToday ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: barH,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: d.isToday ? AppColors.primary : const Color(0xFFa7f3d0),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.day,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w500,
                          color: d.isToday ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: const Color(0xFFa7f3d0), label: 'Hari lalu'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.primary, label: 'Hari ini'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
        ],
      );
}

// ── Insight Section ────────────────────────────────────────────────────────────
class _InsightSection extends StatelessWidget {
  final List<_DashInsight> insights;
  const _InsightSection({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Insight Minggu Ini',
                    style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text('Analisis otomatis untukmu',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              ]),
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map((ins) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: ins.bg, borderRadius: BorderRadius.circular(9)),
                      child: Icon(ins.icon, size: 15, color: ins.iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ins.title,
                            style: GoogleFonts.dmSans(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(ins.sub,
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

// ── At-Risk Section ────────────────────────────────────────────────────────────
class _AtRiskSection extends StatelessWidget {
  final List<_AtRisk> atRisk;
  const _AtRiskSection({required this.atRisk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFf97316)),
            const SizedBox(width: 6),
            Text('Perlu Perhatian',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ]),
          const SizedBox(height: 12),
          ...atRisk.map((r) {
            final colors = switch (r.level) {
              'high' => (dot: const Color(0xFFef4444), badge: const Color(0xFFfef2f2), text: const Color(0xFFdc2626), item: const Color(0xFFfff8f8)),
              'mid'  => (dot: const Color(0xFFf59e0b), badge: const Color(0xFFfff7ed), text: const Color(0xFFea580c), item: const Color(0xFFfffbf5)),
              _      => (dot: const Color(0xFF22c55e), badge: const Color(0xFFdcfce7), text: const Color(0xFF16a34a), item: const Color(0xFFf0fdf4)),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.item,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: colors.dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.name,
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: colors.badge, borderRadius: BorderRadius.circular(20)),
                    child: Text(r.label,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, fontWeight: FontWeight.w700, color: colors.text)),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Filter Tab ─────────────────────────────────────────────────────────────────
class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterTab({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.muted,
                )),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                  style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.primary,
                  )),
              ),
            ],
          ),
        ),
      );
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 40),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.primaryLighter, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.eco_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada habit',
            style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text('Mulai buat habit pertamamu!',
            style: GoogleFonts.dmSans(color: AppColors.muted)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Habit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ]),
      );
}
