import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

enum AlertType { error, success, warning }

class HtAlert extends StatelessWidget {
  final AlertType type;
  final String message;

  const HtAlert({super.key, required this.type, required this.message});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, textColor) = switch (type) {
      AlertType.error => (
          AppColors.errorBg,
          AppColors.error.withOpacity(0.3),
          Icons.error_outline_rounded,
          AppColors.error,
        ),
      AlertType.success => (
          AppColors.successBg,
          AppColors.border,
          Icons.check_circle_outline_rounded,
          AppColors.primaryMid,
        ),
      AlertType.warning => (
          AppColors.warningBg,
          AppColors.warning.withOpacity(0.3),
          Icons.warning_amber_rounded,
          AppColors.warning,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
