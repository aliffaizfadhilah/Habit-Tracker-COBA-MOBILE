// Standard category values (lowercase, matching backend/web)
const habitCategoryOptions = [
  (value: 'kesehatan',        label: 'Kesehatan'),
  (value: 'ilmu_pengetahuan', label: 'Ilmu Pengetahuan'),
  (value: 'spiritual',        label: 'Spiritual'),
  (value: 'finansial',        label: 'Finansial'),
  (value: 'personal',         label: 'Personal'),
  (value: 'lainnya',          label: 'Lainnya'),
];

const standardCategoryValues = [
  'kesehatan', 'ilmu_pengetahuan', 'spiritual', 'finansial', 'personal',
];

class Habit {
  final int idHabit;
  final String title;
  final String category;
  final String? periodeStart;
  final String? periodeEnd;
  final int currentStreak;
  final int longestStreak;
  final double progressPercent;
  final int totalPeriodDays;
  final int totalCompletedDays;
  final String? reminderTime;
  final bool reminderEnabled;
  final bool checkedToday;

  const Habit({
    required this.idHabit,
    required this.title,
    required this.category,
    this.periodeStart,
    this.periodeEnd,
    required this.currentStreak,
    required this.longestStreak,
    required this.progressPercent,
    required this.totalPeriodDays,
    required this.totalCompletedDays,
    this.reminderTime,
    required this.reminderEnabled,
    required this.checkedToday,
  });

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        idHabit: json['id_habit'] ?? json['id'] ?? 0,
        title: json['title'] ?? json['name'] ?? '',
        category: json['category'] ?? '',
        periodeStart: json['periode_start'],
        periodeEnd: json['periode_end'],
        currentStreak: json['current_streak'] ?? 0,
        longestStreak: json['longest_streak'] ?? 0,
        progressPercent: (json['progress_percent'] ?? 0).toDouble(),
        totalPeriodDays: json['total_period_days'] ?? 0,
        totalCompletedDays: json['total_completed_days'] ?? 0,
        reminderTime: json['reminder_time'],
        reminderEnabled: json['reminder_enabled'] ?? false,
        checkedToday: json['checked_today'] ?? false,
      );

  Habit copyWith({bool? checkedToday, bool? reminderEnabled, String? reminderTime}) => Habit(
        idHabit: idHabit,
        title: title,
        category: category,
        periodeStart: periodeStart,
        periodeEnd: periodeEnd,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        progressPercent: progressPercent,
        totalPeriodDays: totalPeriodDays,
        totalCompletedDays: totalCompletedDays,
        reminderTime: reminderTime ?? this.reminderTime,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        checkedToday: checkedToday ?? this.checkedToday,
      );

  bool get isComplete => progressPercent >= 100;

  String get categoryDisplay {
    final found = habitCategoryOptions
        .where((o) => o.value == category.toLowerCase().replaceAll(' ', '_'))
        .cast<({String value, String label})?>()
        .firstOrNull;
    if (found != null) return found.label;
    // Legacy values
    switch (category.toLowerCase().replaceAll(' ', '_')) {
      case 'mental': return 'Mental';
      case 'produktivitas': return 'Produktivitas';
      default: return category; // custom category
    }
  }

  bool get isReminderMissed {
    if (!reminderEnabled || reminderTime == null || checkedToday) return false;
    final now = DateTime.now();
    final parts = reminderTime!.split(':');
    if (parts.length < 2) return false;
    final reminderHour = int.tryParse(parts[0]) ?? 0;
    final reminderMin = int.tryParse(parts[1]) ?? 0;
    return now.hour > reminderHour ||
        (now.hour == reminderHour && now.minute >= reminderMin);
  }
}
