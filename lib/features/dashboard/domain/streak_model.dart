class ActivityLog {
  final int id;
  final int idHabit;
  final String? habitTitle;
  final String date;
  final int status;

  const ActivityLog({
    required this.id,
    required this.idHabit,
    this.habitTitle,
    required this.date,
    required this.status,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'] ?? 0,
        idHabit: json['id_habit'] ?? 0,
        habitTitle: json['habit_title'],
        date: json['date'] ?? '',
        status: json['status'] ?? 0,
      );
}

class WeeklyBar {
  final String day;
  final int val;
  final bool isToday;
  const WeeklyBar({required this.day, required this.val, required this.isToday});
}

class StreakSummary {
  final int totalHabits;
  final int checkedToday;
  final int totalCurrentStreak;
  final int longestStreak;
  final double avgProgress;

  const StreakSummary({
    required this.totalHabits,
    required this.checkedToday,
    required this.totalCurrentStreak,
    required this.longestStreak,
    required this.avgProgress,
  });

  factory StreakSummary.fromJson(Map<String, dynamic> json) {
    // /streak → { data: [...habits], summary: { total_habits, total_current_streak, ... } }
    // /streak/summary → { data: { total_habits, total_current_streak, ... } }
    final habits = json['data'] is List ? json['data'] as List : null;
    final summary = json['summary'] as Map<String, dynamic>?
        ?? (json['data'] is Map ? json['data'] as Map<String, dynamic> : null)
        ?? json;

    final checkedToday = habits != null
        ? habits.where((h) => h['checked_today'] == true).length
        : 0;

    return StreakSummary(
      totalHabits: (summary['total_habits'] ?? 0) as int,
      checkedToday: checkedToday,
      totalCurrentStreak: (summary['total_current_streak'] ?? 0) as int,
      longestStreak: (summary['longest_streak'] ?? 0) as int,
      avgProgress: (summary['avg_progress'] ?? 0).toDouble(),
    );
  }
}
