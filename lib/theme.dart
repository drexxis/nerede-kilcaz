import 'package:flutter/material.dart';

class T {
  static const green = Color(0xFF3B82F6);
  static const green600 = Color(0xFF2563EB);
  static const green700 = Color(0xFF1D4ED8);
  static const green800 = Color(0xFF1E40AF);
  static const green900 = Color(0xFF1E3A8A);
  static const greenLight = Color(0xFFEFF6FF);
  static const gold = Color(0xFFC9A24B);
  static const goldBright = Color(0xFFE3B84F);
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const cream = Color(0xFFF2F5F9);
  static const paper = Color(0xFFFFFFFF);
  static const bodyBg = Color(0xFFEEF1F5);
  static const darkBg = Color(0xFF0A0F17);
  static const darkCream = Color(0xFF0E1622);
  static const darkPaper = Color(0xFF131C29);
  static const darkInk = Color(0xFFE7EDF5);
  static const darkInkSoft = Color(0xFF94A3B8);
  static const darkLine = Color(0xFF223047);
  static const danger = Color(0xFFB3261E);
  static const dangerBg = Color(0xFFFDE8E8);
}

/// Ekran arka planı (koyu/açık temaya göre). Kabuk dışında açılan ekranlar
/// Scaffold'larında bunu kullanır.
Color ctxBodyBg(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkBg : T.bodyBg;

ThemeData buildLight() {
  final scheme = ColorScheme.fromSeed(
    seedColor: T.green,
    brightness: Brightness.light,
    primary: T.green600,
    surface: T.paper,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.bodyBg,
    fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Helvetica', 'Arial'],
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: T.bodyBg,
      foregroundColor: T.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: T.ink,
        fontFamily: 'Segoe UI',
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: T.line,
    cardTheme: const CardThemeData(
      color: T.paper,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.green600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.danger),
      ),
      labelStyle: const TextStyle(color: T.inkSoft, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: T.green600,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: T.ink,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: T.line),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: T.darkBg,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: T.ink),
      bodySmall: TextStyle(color: T.inkSoft),
    ),
  );
}

ThemeData buildDark() {
  final scheme = ColorScheme.fromSeed(
    seedColor: T.green,
    brightness: Brightness.dark,
    primary: T.green,
    surface: T.darkPaper,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.darkBg,
    fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Helvetica', 'Arial'],
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: T.darkBg,
      foregroundColor: T.darkInk,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: T.darkInk,
        fontFamily: 'Segoe UI',
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: T.darkLine,
    cardTheme: const CardThemeData(
      color: T.darkPaper,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.darkPaper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.darkLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.darkLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: T.green, width: 1.5),
      ),
      labelStyle: const TextStyle(color: T.darkInkSoft, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: T.green600,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: T.darkInk,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: T.darkLine),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: T.darkInk),
      bodySmall: TextStyle(color: T.darkInkSoft),
    ),
  );
}

Color ctxInk(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkInk : T.ink;
Color ctxInkSoft(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkInkSoft : T.inkSoft;
Color ctxLine(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkLine : T.line;
Color ctxPaper(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkPaper : T.paper;
Color ctxCream(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.darkCream : T.cream;
Color ctxGreenLight(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0x293B82F6)
    : T.greenLight;
Color ctxGold(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? T.goldBright : T.gold;
