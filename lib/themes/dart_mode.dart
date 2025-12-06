import 'package:flutter/material.dart';/// Тёмная тема в том же ключе
final ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,

    surface: Color(0xFF1C1C1E),

    primary: Color(0xFF5BA4F5),      // светлее синий для dark mode
    onPrimary: Colors.black,

    secondary: Color(0xFF8E8E93),
    onSecondary: Colors.black,
    tertiary: Color(0xFF636366),
    onTertiary: Colors.white,

    error: Color(0xFFFF453A),
    onError: Colors.black,

    onSurface: Colors.white,

    primaryContainer: Color(0xFF1E3A5F),
    secondaryContainer: Color(0xFF2C2C2E),
  ),

  scaffoldBackgroundColor: const Color(0xFF000000),

  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF1C1C1E),
    foregroundColor: Colors.white,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
);