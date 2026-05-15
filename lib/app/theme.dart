import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FreshLoop palette (visual direction "Theme A").
class AppColors {
  AppColors._();
  static const seed = Color(0xFF0E9F6E); // vivid trail green (primary)
  static const accent = Color(0xFFF59E0B); // amber — reserved for the primary CTA + top score
  static const tierGood = Color(0xFF0E9F6E);
  static const tierPartial = Color(0xFFF59E0B);
  static const tierPoor = Color(0xFFEF4444);
}

/// Material 3 theme with the distinctive Sora (display) + DM Sans (body) pairing.
final ThemeData freshLoopTheme = () {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.sora(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.sora(textStyle: base.textTheme.displayMedium, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.sora(textStyle: base.textTheme.headlineLarge, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.sora(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.sora(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.seed,
      thumbColor: AppColors.seed,
      inactiveTrackColor: Color(0x400E9F6E), // ~25% trail green
    ),
  );
}();
