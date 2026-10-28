import 'package:flutter/material.dart';

abstract final class BarroTheme {
  static const primary = Color(0xFFB84D34);
  static const background = Color(0xFFFFF8F5);
  static const text = Color(0xFF1E1B19);
  static const secondary = Color(0xFF57423D);
  static const placeholder = Color(0xFF806B64);
  static const border = Color(0xFFD7C6BE);
  static const success = Color(0xFF28704F);
  static const error = Color(0xFFB42318);

  static TextStyle type(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    Color color = text,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    fontVariations: [
      FontVariation('wght', weight.value.toDouble()),
      const FontVariation('opsz', 14),
    ],
    color: color,
    letterSpacing: 0,
  );

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
    ).copyWith(primary: primary, surface: background, error: error),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: primary),
  );
}
