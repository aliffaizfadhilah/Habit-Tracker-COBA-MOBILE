import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: GoogleFonts.dmSansTextTheme().copyWith(
          displayLarge: GoogleFonts.syne(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
          displayMedium: GoogleFonts.syne(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          headlineMedium: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          titleLarge: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          bodyLarge: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColors.inkBody,
          ),
          bodyMedium: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.inkBody,
          ),
          bodySmall: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          labelStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          hintStyle: GoogleFonts.dmSans(color: AppColors.subtle, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          iconTheme: const IconThemeData(color: AppColors.ink),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.primaryLighter,
          selectedColor: AppColors.primaryLight,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.primaryMid,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.subtle,
          selectedLabelStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 11),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
      );
}

// Shared card decoration (same as web shadow-card)
BoxDecoration cardDecoration({
  double radius = 16,
  bool shadow = true,
  bool hovered = false,
}) =>
    BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: hovered ? AppColors.borderMid : AppColors.border,
        width: 1,
      ),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: hovered
                    ? const Color(0xFF16a34a).withOpacity(0.10)
                    : Colors.black.withOpacity(0.05),
                blurRadius: hovered ? 24 : 12,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
