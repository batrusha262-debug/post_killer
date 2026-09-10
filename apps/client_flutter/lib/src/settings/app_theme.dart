import 'package:flutter/material.dart';

import 'app_settings.dart';

ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final slay = settings.appearance == AppAppearance.slay;
  var colors = ColorScheme.fromSeed(
    seedColor: slay ? const Color(0xFFCD258B) : const Color(0xFF4263EB),
    brightness: brightness,
    contrastLevel: 0.2,
    dynamicSchemeVariant: slay
        ? DynamicSchemeVariant.fidelity
        : DynamicSchemeVariant.tonalSpot,
  );
  if (slay) {
    final lavender = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7853C8),
      brightness: brightness,
    );
    colors = colors.copyWith(
      tertiary: lavender.primary,
      onTertiary: lavender.onPrimary,
      tertiaryContainer: lavender.primaryContainer,
      onTertiaryContainer: lavender.onPrimaryContainer,
    );
  }
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surfaceContainerLow,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: settings.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
      selectedLabelTextStyle: TextStyle(
        color: colors.primary,
        fontFamily: 'Roboto',
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colors.onSurfaceVariant,
        fontFamily: 'Roboto',
        fontSize: 11,
      ),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: 0.65),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: settings.compact ? 10 : 16,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        elevation: 1,
        shadowColor: colors.primary.withValues(alpha: 0.22),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.72)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      dividerColor: colors.outlineVariant,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colors.primary, width: 3),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
