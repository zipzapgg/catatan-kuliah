import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF153D32);
  static const accent = Color(0xFF176B50);
  static const List<Color> subjectColors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFE11D48),
    Color(0xFF0D9488),
    Color(0xFF4F46E5),
    Color(0xFFEA580C),
    Color(0xFF475569),
  ];
  static ThemeData lightTheme() => _theme(Brightness.light);
  static ThemeData darkTheme() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF101C18) : const Color(0xFFF5F5EF);
    final surface = dark ? const Color(0xFF1A2A23) : Colors.white;
    final text = dark ? const Color(0xFFECF4EC) : const Color(0xFF1E3028);
    final muted = dark ? const Color(0xFFB1C3B6) : const Color(0xFF5C6B61);
    final border = dark ? const Color(0xFF35483D) : const Color(0xFFE1E6DD);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          primary: dark ? const Color(0xFF9FDBB6) : accent,
          onPrimary: dark ? const Color(0xFF123A27) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF284C39)
              : const Color(0xFFE0EEE2),
          onPrimaryContainer: dark ? const Color(0xFFDEF6E2) : ink,
          surfaceContainerHighest: dark
              ? const Color(0xFF293C30)
              : const Color(0xFFEDF0E8),
          outlineVariant: border,
          error: dark ? const Color(0xFFFFB4A9) : const Color(0xFFAC3327),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    final textTheme = base.textTheme
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          headlineLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 34,
            height: 1.12,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 28,
            height: 1.18,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            height: 1.25,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            height: 1.5,
            color: text,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            height: 1.45,
            color: text,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            height: 1.4,
            color: muted,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: dark ? 0.5 : 0.65,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : muted,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: border),
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFDDEADF) : ink,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: dark ? ink : Colors.white,
        ),
        actionTextColor: dark ? accent : const Color(0xFFC4EAA0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
