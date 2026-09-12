import 'package:flutter/material.dart';

import 'app_settings.dart';

/// The bright desktop workbench is the default product surface. It keeps
/// request editing legible for long sessions and reserves green/red strictly
/// for HTTP outcomes, leaving blue as the only navigation accent.
ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final isSlay = settings.appearance == AppAppearance.slay;
  final accent = isSlay ? const Color(0xFFA78BFA) : const Color(0xFF4C9BFA);
  final canvas = isDark ? const Color(0xFF101725) : const Color(0xFFF7F9FD);
  final surface = isDark ? const Color(0xFF151E2C) : Colors.white;
  final raised = isDark ? const Color(0xFF202B3C) : const Color(0xFFF1F5FB);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: isDark
        ? (isSlay ? const Color(0xFF39295C) : const Color(0xFF173D6E))
        : (isSlay ? const Color(0xFFF0E9FF) : const Color(0xFFDDEBFF)),
    onPrimaryContainer: isDark
        ? const Color(0xFFE7E8FF)
        : const Color(0xFF1A4F91),
    secondary: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF2D8A46),
    onSecondary: Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF173E35)
        : const Color(0xFFDDF8E8),
    onSecondaryContainer: isDark
        ? const Color(0xFFB7F6D7)
        : const Color(0xFF176437),
    tertiary: const Color(0xFFF59E0B),
    onTertiary: const Color(0xFF392200),
    tertiaryContainer: isDark
        ? const Color(0xFF50391B)
        : const Color(0xFFFFF0D0),
    onTertiaryContainer: isDark
        ? const Color(0xFFFFDDA8)
        : const Color(0xFF6A4700),
    error: isDark ? const Color(0xFFFFA9B0) : const Color(0xFFDC4052),
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF50202B) : const Color(0xFFFFE8EB),
    onErrorContainer: isDark
        ? const Color(0xFFFFD9DD)
        : const Color(0xFF8A1D2B),
    surface: surface,
    onSurface: isDark ? const Color(0xFFF0F4FA) : const Color(0xFF1D2939),
    surfaceContainerHighest: raised,
    onSurfaceVariant: isDark
        ? const Color(0xFFACB9CB)
        : const Color(0xFF64748B),
    outline: isDark ? const Color(0xFF40516A) : const Color(0xFFCBD8E8),
    outlineVariant: isDark ? const Color(0xFF2E3B50) : const Color(0xFFE0E8F2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFF0F4FA) : const Color(0xFF1D2939),
    onInverseSurface: isDark ? const Color(0xFF1D2939) : Colors.white,
    inversePrimary: isDark ? const Color(0xFFB8D9FF) : const Color(0xFF246CC4),
  );
  final radius = BorderRadius.circular(9);
  final fieldBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outline),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: settings.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      // The workbench intentionally uses a generous desktop chrome.  It is a
      // stable landmark for the command field rather than a mobile app bar.
      toolbarHeight: 112,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 25,
        fontWeight: FontWeight.w800,
        letterSpacing: -.45,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2433) : const Color(0xFFFCFDFF),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: settings.compact ? 8 : 12,
      ),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: .8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 68),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 68),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      dividerColor: scheme.outlineVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .82),
        border: Border(bottom: BorderSide(color: scheme.primary, width: 4)),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
