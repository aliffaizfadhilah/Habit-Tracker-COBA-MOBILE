import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

// In-app notification overlay — mirip toast web (InAppNotification.tsx)
// Muncul di atas screen, auto hilang setelah 5 detik

class InAppNotificationService {
  static final _key = GlobalKey<_NotificationOverlayState>();

  static Widget overlay() => _NotificationOverlay(key: _key);

  static void show({required String title, required String body}) {
    _key.currentState?.show(title: title, body: body);
  }
}

class _ToastItem {
  final String id;
  final String title;
  final String body;

  _ToastItem({required this.id, required this.title, required this.body});
}

class _NotificationOverlay extends StatefulWidget {
  const _NotificationOverlay({super.key});

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay> {
  final List<_ToastItem> _toasts = [];
  int _nextId = 0;

  void show({required String title, required String body}) {
    final id = '${_nextId++}';
    setState(() => _toasts.add(_ToastItem(id: id, title: title, body: body)));
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _toasts.removeWhere((t) => t.id == id));
    });
  }

  void _dismiss(String id) {
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    if (_toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: _toasts.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ToastWidget(
            toast: t,
            onDismiss: () => _dismiss(t.id),
          ),
        )).toList(),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final _ToastItem toast;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.toast, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.toast.title,
                      style: GoogleFonts.syne(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    Text(
                      widget.toast.body,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.subtle),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
