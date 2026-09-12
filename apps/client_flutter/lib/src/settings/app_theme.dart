import 'package:flutter/material.dart';

import 'app_settings.dart';

/// A calm, high-contrast workspace theme built around long API work sessions.
ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final isMidnight = settings.appearance == AppAppearance.slay;
  final accent = isMidnight ? const Color(0xFFA78BFA) : const Color(0xFF2563EB);
  final surface = isDark ? const Color(0xFF171C27) : const Color(0xFFFFFFFF);
  final canvas = isDark ? const Color(0xFF101521) : const Color(0xFFF4F7FC);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: isDark
        ? (isMidnight ? const Color(0xFF30255B) : const Color(0xFF19376B))
        : (isMidnight ? const Color(0xFFECE7FF) : const Color(0xFFE5EEFF)),
    onPrimaryContainer: isDark
        ? const Color(0xFFE8E1FF)
        : const Color(0xFF193B78),
    secondary: isMidnight ? const Color(0xFF67E8F9) : const Color(0xFF059669),
    onSecondary: Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF123D39)
        : const Color(0xFFDDF8EE),
    onSecondaryContainer: isDark
        ? const Color(0xFFB9F5DF)
        : const Color(0xFF07594B),
    tertiary: isMidnight ? const Color(0xFFF9A8D4) : const Color(0xFFF59E0B),
    onTertiary: const Color(0xFF241300),
    tertiaryContainer: isDark
        ? const Color(0xFF513819)
        : const Color(0xFFFFF0D0),
    onTertiaryContainer: isDark
        ? const Color(0xFFFFDCA5)
        : const Color(0xFF624300),
    error: isDark ? const Color(0xFFFFA4A9) : const Color(0xFFDC3545),
    onError: isDark ? const Color(0xFF5B1019) : Colors.white,
    errorContainer: isDark ? const Color(0xFF4A202A) : const Color(0xFFFFE8EA),
    onErrorContainer: isDark
        ? const Color(0xFFFFD9DC)
        : const Color(0xFF8D1723),
    surface: surface,
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF172033),
    surfaceContainerHighest: isDark
        ? const Color(0xFF252D3C)
        : const Color(0xFFEAF0F8),
    onSurfaceVariant: isDark
        ? const Color(0xFFABB7C8)
        : const Color(0xFF60708A),
    outline: isDark ? const Color(0xFF3B465A) : const Color(0xFFD4DEEC),
    outlineVariant: isDark ? const Color(0xFF2D3748) : const Color(0xFFE3E9F2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF172033),
    onInverseSurface: isDark ? const Color(0xFF172033) : Colors.white,
    inversePrimary: isDark ? const Color(0xFFB9D1FF) : const Color(0xFF245DCE),
  );
  final radius = BorderRadius.circular(12);
  final fieldBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
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
      toolbarHeight: 70,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
        fontWeight: FontWeight.w700,
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
      fillColor: isDark ? const Color(0xFF1D2533) : const Color(0xFFF8FAFD),
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
        color: scheme.onSurfaceVariant.withValues(alpha: .78),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 42),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
