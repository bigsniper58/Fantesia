import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette Fantesia.
///
/// L'affiche est le heros de chaque ecran : le chrome autour reste sombre et
/// discret pour ne pas concurrencer les jaquettes. L'ambre sert d'accent
/// unique (lecture, progression, selection) et n'est jamais utilise en
/// decoration.
class C {
  static const bg = Color(0xFF0E0D14);
  static const surface = Color(0xFF191824);
  static const surfaceHigh = Color(0xFF232231);
  static const amber = Color(0xFFE8B04B);
  static const text = Color(0xFFEDEAF3);
  static const textDim = Color(0xFF9A96AD);
  static const danger = Color(0xFFE2685B);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
    bodyColor: C.text,
    displayColor: C.text,
  );

  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: C.amber,
      onPrimary: Colors.black,
      secondary: C.amber,
      surface: C.surface,
      onSurface: C.text,
      error: C.danger,
    ),
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.amber.withValues(alpha: 0.18),
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.amber, width: 1.5),
      ),
      hintStyle: const TextStyle(color: C.textDim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.amber,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2937), space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.amber),
  );
}
