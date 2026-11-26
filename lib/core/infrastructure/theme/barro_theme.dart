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
    datePickerTheme: DatePickerThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      headerBackgroundColor: primary,
      headerForegroundColor: Colors.white,
      headerHelpStyle: type(
        13,
        18,
        weight: FontWeight.w600,
        color: Colors.white,
      ),
      headerHeadlineStyle: type(
        26,
        32,
        weight: FontWeight.w700,
        color: Colors.white,
      ),
      weekdayStyle: type(12, 16, weight: FontWeight.w600, color: placeholder),
      dayStyle: type(14, 20, weight: FontWeight.w500),
      yearStyle: type(14, 20, weight: FontWeight.w500),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (estados) =>
            estados.contains(WidgetState.selected) ? Colors.white : primary,
      ),
      todayBorder: const BorderSide(color: primary, width: 1.5),
      dividerColor: border,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: secondary,
        textStyle: type(14, 20, weight: FontWeight.w600),
      ),
      confirmButtonStyle: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: type(14, 20, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
