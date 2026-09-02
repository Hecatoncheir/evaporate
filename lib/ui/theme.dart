import 'package:flutter/material.dart';

/// Тёмная тема «холодного пара»: приложение живёт в полноэкранном окне
/// рядом с играми, поэтому светлой темы здесь намеренно нет.
class EvaporateTheme {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF151B23);
  static const surfaceHigh = Color(0xFF1D242E);
  static const outline = Color(0xFF2A3441);
  static const primary = Color(0xFF4FC3F7);
  static const accent = Color(0xFF7DD3C0);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B98A5);

  /// Основной шрифт интерфейса: нейтральный, хорошо читается в плотных
  /// списках, где текста много и он мелкий.
  static const fontFamily = 'Nunito Sans';

  /// Заголовки набираются округлым Nunito: он мягче и отделяет заголовок
  /// от текста лучше, чем один только размер.
  static const displayFontFamily = 'Nunito';

  /// Пути, размеры и прочее, что читают глазами по знакам, а не словами.
  static const monoFontFamily = 'JetBrains Mono';

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF06202B),
        secondary: accent,
        onSecondary: Color(0xFF06202B),
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceHigh,
        outline: outline,
        error: danger,
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        space: 1,
        thickness: 1,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
            fontFamily: fontFamily,
          )
          .copyWith(
            // Заголовкам — второе семейство: разница в начертании работает
            // там, где разница в размере уже исчерпана.
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            displayMedium: base.textTheme.displayMedium?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            displaySmall: base.textTheme.displaySmall?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: textPrimary,
            ),
          ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF10151C),
        indicatorColor: Color(0x334FC3F7),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outline),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: outline,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: outline),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
