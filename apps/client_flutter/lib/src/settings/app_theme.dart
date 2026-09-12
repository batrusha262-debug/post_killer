import 'package:flutter/material.dart';

import 'app_settings.dart';

/// A dense, terminal-inspired workbench for long API investigation sessions.
///
/// The accent is deliberately cool blue rather than a conventional success
/// green: HTTP outcome colours remain reserved for outcomes, while blue marks
/// the current command and focus state.
ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final isSlay = settings.appearance == AppAppearance.slay;
  final accent = isSlay ? const Color(0xFFA78BFA) : const Color(0xFF4EA1FF);
  final canvas = isDark ? const Color(0xFF090E14) : const Color(0xFFF2F5F8);
  final surface = isDark ? const Color(0xFF0D141D) : const Color(0xFFFBFCFD);
  final raised = isDark ? const Color(0xFF121D28) : const Color(0xFFF4F7FA);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: isDark ? const Color(0xFF06111F) : Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF14314F)
        : const Color(0xFFDCEBFB),
    onPrimaryContainer: isDark
        ? const Color(0xFFD7E9FF)
        : const Color(0xFF10385E),
    secondary: isSlay ? const Color(0xFFD8B4FE) : const Color(0xFF7DD3FC),
    onSecondary: const Color(0xFF07121F),
    secondaryContainer: isDark
        ? const Color(0xFF12303B)
        : const Color(0xFFD9F4FB),
    onSecondaryContainer: isDark
        ? const Color(0xFFC5F0FC)
        : const Color(0xFF123B48),
    tertiary: const Color(0xFFFBBF24),
    onTertiary: const Color(0xFF2C2000),
    tertiaryContainer: isDark
        ? const Color(0xFF473615)
        : const Color(0xFFFFF1C7),
    onTertiaryContainer: isDark
        ? const Color(0xFFFFE8A8)
        : const Color(0xFF5A4300),
    error: isDark ? const Color(0xFFFFA4AB) : const Color(0xFFC6283D),
    onError: isDark ? const Color(0xFF580716) : Colors.white,
    errorContainer: isDark ? const Color(0xFF471923) : const Color(0xFFFFE7E9),
    onErrorContainer: isDark
        ? const Color(0xFFFFD9DD)
        : const Color(0xFF7E1020),
    surface: surface,
    onSurface: isDark ? const Color(0xFFE7EDF5) : const Color(0xFF17202A),
    surfaceContainerHighest: raised,
    onSurfaceVariant: isDark
        ? const Color(0xFF99AABD)
        : const Color(0xFF596A7D),
    outline: isDark ? const Color(0xFF2A3B4E) : const Color(0xFFCED8E3),
    outlineVariant: isDark ? const Color(0xFF1B2A39) : const Color(0xFFE0E7EF),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFE7EDF5) : const Color(0xFF17202A),
    onInverseSurface: isDark ? const Color(0xFF17202A) : Colors.white,
    inversePrimary: isDark ? const Color(0xFFB7D8FF) : const Color(0xFF1766B7),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: scheme.outline),
  );
  final labelStyle = TextStyle(
    color: scheme.onSurfaceVariant,
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'monospace',
    splashFactory: InkSparkle.splashFactory,
    visualDensity: settings.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontFamily: 'monospace',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0A1119) : Colors.white,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: settings.compact ? 8 : 11,
      ),
      hintStyle: labelStyle,
      labelStyle: labelStyle,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontFamily: 'monospace',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dividerColor: scheme.outlineVariant,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
