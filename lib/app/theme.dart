import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/tier.dart';

/// FreshLoop palette (visual direction "Theme A": fresh-air cartographic).
class AppColors {
  AppColors._();
  static const seed = Color(0xFF0E9F6E); // vivid trail green (primary)
  static const seedDark = Color(0xFF065F46); // deep pine — gradients/headers
  static const accent = Color(0xFFF59E0B); // amber — reserved for the primary CTA + top score
  static const tierGood = Color(0xFF0E9F6E);
  static const tierPartial = Color(0xFFF59E0B);
  static const tierPoor = Color(0xFFEF4444);
  static const ink = Color(0xFF0F1F1A); // near-black with a green cast

  /// Soft brand gradient for hero surfaces (sign-in, headers).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, seedDark],
  );
}

/// Spacing scale (4-pt grid) so padding/gaps stay consistent across screens.
class Insets {
  Insets._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

const double kRadius = 20; // shared corner radius for cards / sheets / inputs

/// Visual style for one scoring axis (colour + soft container + icon + word).
class AxisStyle {
  final Color color;
  final Color container;
  final IconData icon;
  final String word;
  const AxisStyle(this.color, this.container, this.icon, this.word);
}

/// Per-axis icon (air / hills / scenery) keyed by the axis label.
IconData axisIcon(String axis) => switch (axis.toLowerCase()) {
      'air' => Icons.air_rounded,
      'hills' => Icons.terrain_rounded,
      'scenery' => Icons.photo_camera_back_rounded,
      _ => Icons.eco_rounded,
    };

/// Resolve a [Tier] (+ axis) into a coherent visual style.
AxisStyle axisStyle(String axis, Tier tier) {
  final (color, word) = switch (tier) {
    Tier.good => (AppColors.tierGood, 'good'),
    Tier.partial => (AppColors.tierPartial, 'ok'),
    Tier.poor => (AppColors.tierPoor, 'poor'),
  };
  return AxisStyle(color, color.withValues(alpha: 0.12), axisIcon(axis), word);
}

/// Material 3 theme with the distinctive Sora (display) + DM Sans (body) pairing
/// and a consistent rounded, lightly-elevated surface language.
final ThemeData freshLoopTheme = () {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    primary: AppColors.seed,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  final text = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.sora(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w800),
    displayMedium: GoogleFonts.sora(textStyle: base.textTheme.displayMedium, fontWeight: FontWeight.w800),
    displaySmall: GoogleFonts.sora(textStyle: base.textTheme.displaySmall, fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.sora(textStyle: base.textTheme.headlineLarge, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.sora(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.sora(textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.sora(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF6F8F7),
    textTheme: text,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: base.colorScheme.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: base.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: base.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: base.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      selectedColor: AppColors.seed.withValues(alpha: 0.16),
      labelStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: base.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.seed, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.seed,
      thumbColor: AppColors.seed,
      inactiveTrackColor: const Color(0x330E9F6E),
      overlayColor: const Color(0x1F0E9F6E),
      trackHeight: 5,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
  );
}();
