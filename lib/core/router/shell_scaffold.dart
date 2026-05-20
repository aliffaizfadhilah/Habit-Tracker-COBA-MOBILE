import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
    (icon: Icons.check_box_rounded, label: 'Habit', path: '/habits'),
    (icon: Icons.notifications_rounded, label: 'Reminder', path: '/reminders'),
    (icon: Icons.feed_rounded, label: 'Feed', path: '/feed'),
    (icon: Icons.person_rounded, label: 'Profil', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    final activeIndex = currentIndex < 0 ? 0 : currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final active = i == activeIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(tab.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primaryLighter : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            tab.icon,
                            size: 20,
                            color: active ? AppColors.primary : AppColors.subtle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? AppColors.primary : AppColors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
