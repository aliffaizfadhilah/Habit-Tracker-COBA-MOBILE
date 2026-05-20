import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: HabitTrackerApp()));
}

class HabitTrackerApp extends ConsumerWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HabitTracker',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Overlay in-app notification di atas seluruh app
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            InAppNotificationService.overlay(),
          ],
        );
      },
    );
  }
}
