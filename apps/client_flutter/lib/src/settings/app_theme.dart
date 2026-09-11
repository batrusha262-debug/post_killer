import 'package:flutter/material.dart';

import 'app_settings.dart';

/// A deliberately quiet foundation so request data, not the chrome, is the
/// loudest thing on screen.
ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final isNebula = settings.appearance == AppAppearance.slay;
  final accent = isNebula ? const Color(0xFF8B6CFF) : const Color(0xFF1677FF);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: isDark
        ? (isNebula ? const Color(0xFF302754) : const Color(0xFF153C73))
        : (isNebula ? const Color(0xFFEDE5FF) : const Color(0xFFE3EDFF)),
    onPrimaryContainer: isDark
        ? const Color(0xFFE8DFFF)
        : (isNebula ? const Color(0xFF41207A) : const Color(0xFF153C82)),
    secondary: isNebula ? const Color(0xFFB79AFF) : const Color(0xFF19C37D),
    onSecondary: const Color(0xFF07131A),
    secondaryContainer: isDark
        ? const Color(0xFF123B39)
        : const Color(0xFFD9F8F1),
    onSecondaryContainer: isDark
        ? const Color(0xFFBFF8EE)
        : const Color(0xFF075B53),
    tertiary: isNebula ? const Color(0xFFFFA1C7) : const Color(0xFF8BA6FF),
    onTertiary: const Color(0xFF111827),
    tertiaryContainer: isDark
        ? const Color(0xFF2A315B)
        : const Color(0xFFE7ECFF),
    onTertiaryContainer: isDark
        ? const Color(0xFFE2E7FF)
        : const Color(0xFF27346D),
    error: isDark ? const Color(0xFFFF8A97) : const Color(0xFFD92D4E),
    onError: isDark ? const Color(0xFF46000C) : Colors.white,
    errorContainer: isDark ? const Color(0xFF4B1B29) : const Color(0xFFFFE8EB),
    onErrorContainer: isDark
        ? const Color(0xFFFFD9DE)
        : const Color(0xFF8A1028),
    surface: isDark ? const Color(0xFF202020) : Colors.white,
    onSurface: isDark ? const Color(0xFFE6E6E6) : const Color(0xFF172033),
    surfaceContainerHighest: isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE9EEF6),
    onSurfaceVariant: isDark
        ? const Color(0xFFA7A7A7)
        : const Color(0xFF5C6B82),
    outline: isDark ? const Color(0xFF454545) : const Color(0xFFD5DDE9),
    outlineVariant: isDark ? const Color(0xFF353535) : const Color(0xFFE3E8F0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFE8EDF7) : const Color(0xFF172033),
    onInverseSurface: isDark ? const Color(0xFF172033) : Colors.white,
    inversePrimary: isDark ? const Color(0xFF8CB4FF) : const Color(0xFF245DCE),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF5F7FB),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: settings.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF202020) : Colors.white,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
      ),
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark ? const Color(0xFF202020) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: scheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF242424) : const Color(0xFFF8FAFD),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.8),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: settings.compact ? 8 : 10,
      ),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: .75),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dividerColor: scheme.outlineVariant,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
