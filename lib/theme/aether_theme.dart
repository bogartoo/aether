import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens for Aether — deep night + crimson heart accent.
abstract final class AetherColors {
  static const voidBg = Color(0xFF070B12);
  static const ink = Color(0xFF0A1628);
  static const panel = Color(0xFF121C2A);
  static const panelEdge = Color(0xFF1E3044);
  static const mist = Color(0xFF8BA3B5);
  static const foam = Color(0xFFE8F1F7);
  static const teal = Color(0xFF00E5A8);
  static const tealDeep = Color(0xFF00B4D8);
  static const heart = Color(0xFFE11D48);
  static const heartDeep = Color(0xFFBE123C);
}

ThemeData buildAetherTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AetherColors.teal,
      brightness: Brightness.dark,
      primary: AetherColors.teal,
      secondary: AetherColors.heart,
      surface: AetherColors.panel,
    ),
  );

  final display = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
  final body = GoogleFonts.dmSansTextTheme(base.textTheme);

  return base.copyWith(
    scaffoldBackgroundColor: AetherColors.voidBg,
    textTheme: body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AetherColors.foam,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AetherColors.foam,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        color: AetherColors.foam,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AetherColors.foam,
      ),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.45, color: AetherColors.foam),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.4, color: AetherColors.foam),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AetherColors.foam,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AetherColors.panel,
      hintStyle: const TextStyle(color: AetherColors.mist),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AetherColors.panelEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AetherColors.teal, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}
