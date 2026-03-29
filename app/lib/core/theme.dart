import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTheme — warm, personal, memorial aesthetic.
/// Deep navy + warm amber with cream backgrounds.
class AppTheme {
  AppTheme._();

  // --- Color Palette ---
  static const Color navyDeep = Color(0xFF1A2B4A);
  static const Color navyMid = Color(0xFF243558);
  static const Color navyLight = Color(0xFF2E4270);

  static const Color amber = Color(0xFFD4891A);
  static const Color amberLight = Color(0xFFE8A535);
  static const Color amberPale = Color(0xFFF5C870);

  static const Color cream = Color(0xFFFAF5EC);
  static const Color creamDark = Color(0xFFF0E8D8);

  static const Color textPrimary = Color(0xFF1A2B4A);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textLight = Color(0xFF8A9BB0);

  static const Color bubbleKevin = Color(0xFF243558);
  static const Color bubbleUser = Color(0xFFD4891A);
  static const Color bubbleKevinText = Color(0xFFF5F0E8);
  static const Color bubbleUserText = Color(0xFFFFFFFF);

  static const Color errorRed = Color(0xFFB91C1C);
  static const Color successGreen = Color(0xFF15803D);

  // --- Text Styles ---
  static TextTheme get _textTheme => GoogleFonts.merriweatherTextTheme().copyWith(
        displayLarge: GoogleFonts.merriweather(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: navyDeep,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.merriweather(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: navyDeep,
        ),
        headlineLarge: GoogleFonts.merriweather(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: navyDeep,
        ),
        headlineMedium: GoogleFonts.merriweather(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: navyDeep,
        ),
        titleLarge: GoogleFonts.lato(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: navyDeep,
          letterSpacing: 0.15,
        ),
        titleMedium: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: navyDeep,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: navyDeep,
          letterSpacing: 0.5,
        ),
        labelMedium: GoogleFonts.lato(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textLight,
          letterSpacing: 0.4,
        ),
      );

  // --- Light Theme ---
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: navyDeep,
          onPrimary: cream,
          primaryContainer: navyLight,
          onPrimaryContainer: cream,
          secondary: amber,
          onSecondary: Colors.white,
          secondaryContainer: amberPale,
          onSecondaryContainer: navyDeep,
          surface: cream,
          onSurface: textPrimary,
          surfaceContainerHighest: creamDark,
          error: errorRed,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: cream,
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: navyDeep,
          foregroundColor: cream,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.merriweather(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cream,
            letterSpacing: 0.5,
          ),
          iconTheme: const IconThemeData(color: cream),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: amber,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: amber.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: navyDeep,
            side: const BorderSide(color: navyDeep, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCDD5E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCDD5E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: navyDeep, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorRed),
          ),
          hintStyle: GoogleFonts.lato(
            fontSize: 15,
            color: textLight,
          ),
          labelStyle: GoogleFonts.lato(
            fontSize: 14,
            color: textSecondary,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: navyDeep.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: creamDark,
          selectedColor: navyDeep,
          labelStyle: GoogleFonts.lato(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: navyDeep,
          contentTextStyle: GoogleFonts.lato(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: amber,
          unselectedLabelColor: textLight,
          indicatorColor: amber,
          labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.w400, fontSize: 14),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: amber,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: navyDeep,
          selectedItemColor: amberLight,
          unselectedItemColor: Color(0xFF6B7FA0),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );
}
