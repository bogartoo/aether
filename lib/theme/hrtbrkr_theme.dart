import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Black canvas · pink signal.
class HrtbrkrColors {
  static const black = Color(0xFF000000);
  static const ink = Color(0xFF0A0A0A);
  static const surface = Color(0xFF121214);
  static const raised = Color(0xFF1A1A1E);
  static const line = Color(0xFF2A2A30);
  static const pink = Color(0xFFFF3D8A);
  static const pinkSoft = Color(0xFFFF7AB5);
  static const pinkDim = Color(0x44FF3D8A);
  static const white = Color(0xFFF5F5F7);
  static const mute = Color(0xFF8A8A96);
  static const danger = Color(0xFFFF6B81);
}

ThemeData buildHrtbrkrTheme() {
  final display = GoogleFonts.syneTextTheme();
  final body = GoogleFonts.dmSansTextTheme();

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      surface: HrtbrkrColors.ink,
      primary: HrtbrkrColors.pink,
      onPrimary: Colors.black,
      secondary: HrtbrkrColors.pinkSoft,
      onSurface: HrtbrkrColors.white,
      outline: HrtbrkrColors.line,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: HrtbrkrColors.black,
    dividerColor: HrtbrkrColors.line,
    textTheme: body
        .merge(display)
        .apply(
          bodyColor: HrtbrkrColors.white,
          displayColor: HrtbrkrColors.white,
        )
        .copyWith(
          displayLarge: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: HrtbrkrColors.white,
          ),
          headlineMedium: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: HrtbrkrColors.white,
          ),
          titleLarge: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: HrtbrkrColors.white,
          ),
          bodyLarge: GoogleFonts.dmSans(
            height: 1.45,
            color: HrtbrkrColors.white,
          ),
          bodyMedium: GoogleFonts.dmSans(
            height: 1.4,
            color: HrtbrkrColors.white,
          ),
          labelLarge: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: HrtbrkrColors.white,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HrtbrkrColors.pink,
        foregroundColor: Colors.black,
        disabledBackgroundColor: HrtbrkrColors.pink.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HrtbrkrColors.mute,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HrtbrkrColors.surface,
      hintStyle: GoogleFonts.dmSans(color: HrtbrkrColors.mute),
      labelStyle: GoogleFonts.dmSans(color: HrtbrkrColors.mute),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HrtbrkrColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HrtbrkrColors.pink, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: HrtbrkrColors.raised,
      textStyle: GoogleFonts.dmSans(color: HrtbrkrColors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

BoxDecoration hrtbrkrBackdrop() {
  return const BoxDecoration(
    color: HrtbrkrColors.black,
    gradient: RadialGradient(
      center: Alignment(0, -0.7),
      radius: 1.05,
      colors: [
        Color(0x33FF3D8A),
        Color(0x0D0A0A0A),
        HrtbrkrColors.black,
      ],
      stops: [0.0, 0.42, 1.0],
    ),
  );
}
