import 'package:flutter/material.dart';

/// Тёмная тема приложения Garage.
/// 
/// Здесь собраны все цвета и стили в одном месте, чтобы
/// менять внешний вид можно было из одной точки.
class AppTheme {
  // Приватный конструктор — мы не будем создавать объекты AppTheme,
  // используем только статические поля и методы.
  AppTheme._();

  // === ЦВЕТА GARAGE ===
  
  /// Основной акцент — оранжевый, как предупреждающие знаки в гараже.
  /// Используется для кнопок, активных элементов, выделений.
  static const Color accent = Color(0xFFFF8C42);

  /// Фон приложения — почти чёрный, но не чистый, чтобы глаза не уставали.
  static const Color background = Color(0xFF121212);

  /// Фон карточек и панелей — чуть светлее фона, чтобы "отделялись".
  static const Color surface = Color(0xFF1E1E1E);

  /// Ещё светлее — для нажатых/выделенных карточек.
  static const Color surfaceLight = Color(0xFF2A2A2A);

  /// Основной цвет текста — светло-серый, не чисто белый (мягче для глаз).
  static const Color textPrimary = Color(0xFFE0E0E0);

  /// Второстепенный текст — для дат, подписей, мелких пояснений.
  static const Color textSecondary = Color(0xFF9E9E9E);

  // === ЦВЕТА СТАТУСОВ ПРОЕКТА ===
  // По схеме БД: idea / in_progress / frozen / done
  static const Color statusIdea = Color(0xFF64B5F6);       // синий — "идея"
  static const Color statusInProgress = Color(0xFFFF8C42); // оранжевый — "в работе"
  static const Color statusFrozen = Color(0xFF78909C);     // серо-синий — "заморожен"
  static const Color statusDone = Color(0xFF66BB6A);       // зелёный — "готово"

  // === ГОТОВАЯ ТЕМА ===

  /// Собираем ThemeData — то, что Flutter ждёт на вход MaterialApp.
  static ThemeData get dark {
    return ThemeData(
      // Тёмная основа — берём готовую базу и перекрашиваем под себя.
      brightness: Brightness.dark,

      // Цветовая схема — современный подход Flutter (Material 3).
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.black,      // текст НА оранжевой кнопке
        onSurface: textPrimary,       // текст НА тёмной поверхности
      ),

      // Цвет фона "полотна" приложения (то, что за карточками).
      scaffoldBackgroundColor: background,

      // Стиль AppBar — верхней панели.
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      // Общий стиль текста.
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
    );
  }
}
