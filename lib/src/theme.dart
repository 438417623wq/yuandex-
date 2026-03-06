import 'package:flutter/material.dart';

class AppPalette {
  static const Color primary = Color(0xFF0B6E4F);
  static const Color accent = Color(0xFFFF9F1C);
  static const Color muted = Color(0xFF5C6E7B);
  static const Color ink = Color(0xFF1D2C38);
  static const Color card = Color(0xD9FFFFFF);
  static const Color border = Color(0x33A6B8C8);
  static const Color codeBg = Color(0xFF111B2D);
  static const Color codeFg = Color(0xFFC7D4E9);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Sora',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
    ).copyWith(primary: AppPalette.primary, secondary: AppPalette.accent),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppPalette.ink,
      ),
      bodyMedium: TextStyle(color: AppPalette.muted, height: 1.4),
    ),
  );
}
