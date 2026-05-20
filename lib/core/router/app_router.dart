import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/riwayat_screen.dart';
import '../../features/habit/presentation/screens/habit_list_screen.dart';
import '../../features/habit/presentation/screens/habit_detail_screen.dart';
import '../../features/post/presentation/screens/feed_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reminder/presentation/screens/reminder_screen.dart';
import '../widgets/loading_widget.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),

      // Auth
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/otp-verify',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return OtpScreen(email: extra['email'] ?? '', mode: extra['mode'] ?? 'register');
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return ResetPasswordScreen(email: extra['email'] ?? '', otp: extra['otp'] ?? '');
        },
      ),

      // Riwayat (pushed from dashboard, outside shell)
      GoRoute(path: '/riwayat', builder: (_, __) => const RiwayatScreen()),

      // Habit detail (pushed from dashboard)
      GoRoute(
        path: '/habit-detail/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return HabitDetailScreen(idHabit: id);
        },
      ),

      // Main app shell (bottom nav)
      ShellRoute(
        builder: (_, __, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/habits', builder: (_, __) => const HabitListScreen()),
          GoRoute(path: '/reminders', builder: (_, __) => const ReminderScreen()),
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authInitProvider).whenData((_) {
      final user = ref.read(currentUserProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(user != null ? '/dashboard' : '/login');
      });
    });

    ref.watch(authInitProvider).whenOrNull(
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/login');
        });
      },
    );

    return const Scaffold(
      backgroundColor: Color(0xFFf7faf8),
      body: LoadingWidget(),
    );
  }
}
