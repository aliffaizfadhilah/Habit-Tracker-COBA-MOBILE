class ApiConstants {
  // 10.0.2.2 = Android emulator → host machine
  // Untuk physical device: ganti dengan IP WiFi komputer (ipconfig di CMD)
  static const String baseUrl = 'http://192.168.30.202:5173/api';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyForgotOtp = '/auth/forgot-password/verify';
  static const String resetPassword = '/auth/reset-password';
  static const String me = '/me';

  // Profile
  static const String profile = '/profile';
  static const String changePasswordRequest = '/profile/change-password/request';
  static const String changePasswordVerify = '/profile/change-password/verify';
  static const String changePassword = '/profile/change-password';

  // Habits
  static const String habits = '/habits';

  // Streak
  static const String streak = '/streak';
  static const String streakSummary = '/streak/summary';

  // Activity Log
  static const String activityLogs = '/activity-logs';

  // Posts
  static const String posts = '/posts';

  // SSE streams
  static const String feedStream   = '/feed/stream';
  static const String habitsStream = '/habits/stream';

  // Server root URL (for resolving relative storage paths like /storage/...)
  static String get serverUrl {
    final idx = baseUrl.lastIndexOf('/api');
    return idx >= 0 ? baseUrl.substring(0, idx) : baseUrl;
  }
}
