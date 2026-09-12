import 'package:flutter/material.dart';

import 'app_settings.dart';

/// The workbench borrows from a terminal rather than a dashboard: thin grid
/// lines, compact controls and one vivid green action color keep an API
/// request legible at a glance.
ThemeData buildAppTheme(AppSettings settings, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final green = settings.appearance == AppAppearance.slay
      ? const Color(0xFFA78BFA)
      : const Color(0xFF91FF39);
  final canvas = dark ? const Color(0xFF071014) : const Color(0xFFF4F7F6);
  final surface = dark ? const Color(0xFF091317) : Colors.white;
  final raised = dark ? const Color(0xFF101D22) : const Color(0xFFE8EFED);
  final ink = dark ? const Color(0xFFD7E4E9) : const Color(0xFF15272D);
  final muted = dark ? const Color(0xFF8BA1AB) : const Color(0xFF607982);
  final line = dark ? const Color(0xFF1C3038) : const Color(0xFFCFDCDA);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: green,
    onPrimary: const Color(0xFF102007),
    primaryContainer: dark ? const Color(0xFF163020) : const Color(0xFFDDF8C6),
    onPrimaryContainer: dark
        ? const Color(0xFFC4FFA3)
        : const Color(0xFF255113),
    secondary: dark ? const Color(0xFF5EEB72) : const Color(0xFF21893B),
    onSecondary: Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF0B3420)
        : const Color(0xFFD7F6DE),
    onSecondaryContainer: dark
        ? const Color(0xFFABF8B8)
        : const Color(0xFF155E28),
    tertiary: const Color(0xFFFFD43B),
    onTertiary: const Color(0xFF2C2500),
    tertiaryContainer: dark ? const Color(0xFF40360B) : const Color(0xFFFFF0B3),
    onTertiaryContainer: dark
        ? const Color(0xFFFFEA8A)
        : const Color(0xFF5F5000),
    error: dark ? const Color(0xFFFF6670) : const Color(0xFFD92D35),
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF3E1820) : const Color(0xFFFFE2E4),
    onErrorContainer: dark ? const Color(0xFFFFB6BD) : const Color(0xFF8E161E),
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: raised,
    onSurfaceVariant: muted,
    outline: dark ? const Color(0xFF36505A) : const Color(0xFFB8C9C7),
    outlineVariant: line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: ink,
    onInverseSurface: surface,
    inversePrimary: green,
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: BorderSide(color: scheme.outline),
  );
  final type = Typography.material2021(platform: TargetPlatform.macOS).white;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    splashFactory: InkRipple.splashFactory,
    visualDensity: settings.compact
        ? VisualDensity.compact
        : const VisualDensity(horizontal: -2, vertical: -2),
    fontFamily: 'monospace',
    textTheme: type.copyWith(
      bodyMedium: TextStyle(color: ink, fontSize: 13),
      bodySmall: TextStyle(color: muted, fontSize: 11),
      labelLarge: TextStyle(
        color: ink,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(color: muted, fontSize: 12),
      titleMedium: TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      titleTextStyle: TextStyle(
        color: ink,
        fontFamily: 'monospace',
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: dark ? const Color(0xFF0B171C) : const Color(0xFFFCFDFC),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: green, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: TextStyle(color: muted.withValues(alpha: .88), fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(42, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: raised,
      side: BorderSide(color: Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(
        color: ink,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: muted,
      labelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      dividerColor: line,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: green, width: 2),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
