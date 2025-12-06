import 'package:flutter/material.dart';

/// LIGHT — графит-минимал с акцентом
final ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,

    // Базовые слои
    surface: Color(0xFFF5F5F7),      // светлее, мягче для глаз

    // Акцент — тонкий синий (как у вас в tertiary)
    primary: Color(0xFF4A90E2),      // приятный синий
    onPrimary: Colors.white,

    // Вторичные — серые
    secondary: Color(0xFF8E8E93),
    onSecondary: Colors.white,
    tertiary: Color(0xFF636366),     // темнее серый
    onTertiary: Colors.white,

    // Ошибки
    error: Color(0xFFFF3B30),        // более заметный красный
    onError: Colors.white,

    // Текст
    onSurface: Color(0xFF1C1C1E),

    // Контейнеры
    primaryContainer: Color(0xFFE3F2FD),   // светло-синий
    secondaryContainer: Color(0xFFE5E5EA),
  ),

  scaffoldBackgroundColor: const Color(0xFFFFFFFF),  // чистый белый

  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFFF5F5F7),
    foregroundColor: Color(0xFF1C1C1E),
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1C1C1E),
    ),
  ),
);