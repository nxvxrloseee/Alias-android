import 'package:flutter/material.dart';

/// Палитра «игрового стола»: зелёное сукно, белая карточка, золотые акценты.
class C {
  static const felt = Color(0xFF1B4A3D);
  static const feltDeep = Color(0xFF143A30);
  static const feltLine = Color(0xFF2B6352);
  static const card = Color(0xFFFBFAF6);
  static const ink = Color(0xFF1D2422);
  static const inkSoft = Color(0xFF5D6B66);
  static const chalk = Color(0xFFE9F1EC);
  static const chalkSoft = Color(0xFFA9C3B8);
  static const gold = Color(0xFFF2B632);
  static const ok = Color(0xFF3CCF7F);
  static const skip = Color(0xFFFF6B57);

  static const teams = [
    Color(0xFFF2B632),
    Color(0xFF5AB4FF),
    Color(0xFFFF7AA8),
    Color(0xFFB48CFF),
    Color(0xFF4FE0C8),
    Color(0xFFFF9A4D),
    Color(0xFFC6E86B),
    Color(0xFFFF5C5C),
    Color(0xFF8FD3FF),
    Color(0xFFE0A3FF),
  ];

  static Color team(int i) => teams[i % teams.length];
}

// Шрифты вариативные, поэтому вес задаём ещё и осью wght.
TextStyle display(
  double size, {
  FontWeight w = FontWeight.w700,
  Color color = C.chalk,
  double? height,
  double? spacing,
}) => TextStyle(
  fontFamily: 'Unbounded',
  fontSize: size,
  fontWeight: w,
  fontVariations: [FontVariation('wght', w.value.toDouble())],
  color: color,
  height: height,
  letterSpacing: spacing,
);

TextStyle body(
  double size, {
  FontWeight w = FontWeight.w400,
  Color color = C.chalk,
  double? height,
}) => TextStyle(
  fontFamily: 'Golos',
  fontSize: size,
  fontWeight: w,
  fontVariations: [FontVariation('wght', w.value.toDouble())],
  color: color,
  height: height,
);

TextStyle label() => body(
  12,
  w: FontWeight.w600,
  color: C.chalkSoft,
).copyWith(letterSpacing: 1.4);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Golos',
    scaffoldBackgroundColor: C.felt,
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: C.ink,
      secondary: C.ok,
      surface: C.feltDeep,
      onSurface: C.chalk,
      error: C.skip,
    ),
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.gold,
      selectionHandleColor: C.gold,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.feltDeep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: display(18),
      contentTextStyle: body(15, color: C.chalkSoft, height: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.chalk,
      contentTextStyle: body(15, w: FontWeight.w600, color: C.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
