import 'package:flutter/material.dart';

class CineXPalette {
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF8B5CF6);
  static const accent = Color(0xFFFFB800);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF39C12);
  static const danger = Color(0xFFE74C3C);
  static const background = Color(0xFF0F1115);
  static const card = Color(0xFF1A1D24);
  static const surface = Color(0xFF242833);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B6C3);
  static const divider = Color(0xFF2F3542);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: CineXPalette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: CineXPalette.primary,
      secondary: CineXPalette.secondary,
      tertiary: CineXPalette.accent,
      error: CineXPalette.danger,
    );

    return _base(scheme);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: CineXPalette.primary,
      onPrimary: Colors.white,
      secondary: CineXPalette.secondary,
      onSecondary: Colors.white,
      tertiary: CineXPalette.accent,
      onTertiary: CineXPalette.background,
      error: CineXPalette.danger,
      onError: Colors.white,
      surface: CineXPalette.card,
      onSurface: CineXPalette.textPrimary,
      surfaceContainerHighest: CineXPalette.surface,
      outline: CineXPalette.divider,
      outlineVariant: CineXPalette.divider,
    );

    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final seedTheme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final textTheme = seedTheme.textTheme
        .apply(
          fontFamily: 'Poppins',
          bodyColor: scheme.brightness == Brightness.dark
              ? CineXPalette.textSecondary
              : const Color(0xFF3D4350),
          displayColor: scheme.brightness == Brightness.dark
              ? CineXPalette.textPrimary
              : const Color(0xFF111827),
        )
        .copyWith(
          displaySmall: seedTheme.textTheme.displaySmall?.copyWith(
            fontSize: 36,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          headlineSmall: seedTheme.textTheme.headlineSmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          titleLarge: seedTheme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          titleMedium: seedTheme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          bodyMedium: seedTheme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
          ),
          labelLarge: seedTheme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        );

    final radius24 = BorderRadius.circular(24);
    final radius18 = BorderRadius.circular(18);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.brightness == Brightness.dark
          ? CineXPalette.background
          : const Color(0xFFF7F8FB),
      fontFamily: 'Poppins',
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      dividerColor: CineXPalette.divider,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.brightness == Brightness.dark
            ? CineXPalette.card
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius24),
        shadowColor: CineXPalette.primary.withAlpha(40),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.dark
            ? CineXPalette.surface.withAlpha(190)
            : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: radius18,
          borderSide: const BorderSide(color: CineXPalette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius18,
          borderSide: const BorderSide(color: CineXPalette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius18,
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius18,
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(
          color: scheme.brightness == Brightness.dark
              ? CineXPalette.textSecondary
              : const Color(0xFF596070),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: scheme.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 52),
          shape: RoundedRectangleBorder(borderRadius: radius18),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 52),
          side: const BorderSide(color: CineXPalette.divider),
          shape: RoundedRectangleBorder(borderRadius: radius18),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius18),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 10,
        backgroundColor: CineXPalette.primary,
        foregroundColor: Colors.white,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withAlpha(55);
          }
          return CineXPalette.surface.withAlpha(210);
        }),
        side: const BorderSide(color: CineXPalette.divider),
        labelStyle: const TextStyle(
          color: CineXPalette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: CineXPalette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: CineXPalette.card.withAlpha(220),
        indicatorColor: scheme.primary.withAlpha(55),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : CineXPalette.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withAlpha(45),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme:
            const IconThemeData(color: CineXPalette.textSecondary),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: CineXPalette.textSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CineXPalette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CineXPalette.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: CineXPalette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CineXPalette.surface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: CineXPalette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CineXPalette.primary,
        linearTrackColor: CineXPalette.divider,
        circularTrackColor: CineXPalette.divider,
      ),
    );
  }
}
