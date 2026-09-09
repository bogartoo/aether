import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AetherColors {
  static const voidBlack = Color(0xFF061018);
  static const deepNavy = Color(0xFF0A1628);
  static const forestNight = Color(0xFF0D2B24);
  static const heartNight = Color(0xFF1A0B14);
  static const panel = Color(0xFF12202E);
  static const panelAlt = Color(0xFF142433);
  static const border = Color(0xFF1E3A4C);
  static const mint = Color(0xFF00E5A8);
  static const cyan = Color(0xFF00B4D8);
  static const heart = Color(0xFFE11D48);
  static const mist = Color(0xFF8BA3B5);
  static const ivory = Color(0xFFE8F1F5);
}

ThemeData buildAetherTheme() {
  final display = GoogleFonts.spaceGroteskTextTheme();
  final body = GoogleFonts.ibmPlexSansTextTheme();

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AetherColors.mint,
      brightness: Brightness.dark,
      primary: AetherColors.mint,
      secondary: AetherColors.heart,
      surface: AetherColors.deepNavy,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AetherColors.voidBlack,
    textTheme: body
        .merge(display)
        .apply(
          bodyColor: AetherColors.ivory,
          displayColor: AetherColors.ivory,
        )
        .copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AetherColors.ivory,
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: AetherColors.ivory,
          ),
          titleLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: AetherColors.ivory,
          ),
          bodyLarge: GoogleFonts.ibmPlexSans(
            height: 1.45,
            color: AetherColors.ivory,
          ),
          bodyMedium: GoogleFonts.ibmPlexSans(
            height: 1.4,
            color: AetherColors.ivory,
          ),
          labelLarge: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w600,
            color: AetherColors.ivory,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AetherColors.mint,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.4,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AetherColors.panel,
      hintStyle: const TextStyle(color: AetherColors.mist),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AetherColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AetherColors.mint, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}

BoxDecoration aetherBackdrop() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AetherColors.deepNavy,
        AetherColors.heartNight,
        AetherColors.forestNight,
        AetherColors.voidBlack,
      ],
      stops: [0, 0.35, 0.7, 1],
    ),
  );
}
