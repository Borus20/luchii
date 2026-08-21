import 'package:flutter/material.dart';

abstract final class LuchiiColors {
  static const bgDeep    = Color(0xFF090806);
  static const bgMid     = Color(0xFF1C1200);
  static const gold      = Color(0xFFFFB700);
  static const goldLight = Color(0xFFFFD649);
  static const ember     = Color(0xFFFF6B00);
  static const emberLight= Color(0xFFFF9A3C);
  static const error     = Color(0xFFFF4560);
  static const text      = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFC4B090);
  static const card      = Color(0x14FFB700);
  static const cardBorder= Color(0x26FFB700);
}

const goldGradient = LinearGradient(
  colors: [LuchiiColors.gold, LuchiiColors.goldLight],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

const wordmarkGradient = LinearGradient(
  colors: [Color(0xFFFFB700), Color(0xFFFFFFFF), Color(0xFFFF6B00)],
  stops: [0, 0.5, 1],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

ThemeData buildLuchiiTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LuchiiColors.bgDeep,
    colorScheme: const ColorScheme.dark(
      primary: LuchiiColors.gold,
      secondary: LuchiiColors.ember,
      surface: LuchiiColors.bgMid,
      error: LuchiiColors.error,
      onPrimary: LuchiiColors.bgDeep,
      onSecondary: LuchiiColors.bgDeep,
      onSurface: LuchiiColors.text,
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: LuchiiColors.text, fontWeight: FontWeight.w900),
      displayMedium: TextStyle(color: LuchiiColors.text, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: LuchiiColors.text, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: LuchiiColors.text, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: LuchiiColors.text),
      bodyMedium: TextStyle(color: LuchiiColors.textMuted),
      labelLarge: TextStyle(color: LuchiiColors.text, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LuchiiColors.gold,
        foregroundColor: LuchiiColors.bgDeep,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LuchiiColors.gold,
        side: const BorderSide(color: LuchiiColors.goldLight, width: 1.5),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LuchiiColors.bgMid,
      indicatorColor: LuchiiColors.card,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: LuchiiColors.gold);
        }
        return const IconThemeData(color: LuchiiColors.textMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: LuchiiColors.gold, fontSize: 12, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: LuchiiColors.textMuted, fontSize: 12);
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: LuchiiColors.bgMid,
      contentTextStyle: TextStyle(color: LuchiiColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: LuchiiColors.cardBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: LuchiiColors.bgDeep,
      foregroundColor: LuchiiColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: LuchiiColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
