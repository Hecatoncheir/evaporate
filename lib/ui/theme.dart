import 'package:flutter/material.dart';

import 'app_colors.dart';
export 'app_colors.dart';

/// Короткий доступ к палитре: `context.colors.textSecondary`.
extension EvaporateColors on BuildContext {
  EvaporatePalette get colors =>
      Theme.of(this).extension<EvaporatePalette>() ?? EvaporatePalette.dark;
}

/// Темы приложения.
class EvaporateTheme {
  const EvaporateTheme._();

  /// Основной шрифт интерфейса: нейтральный, хорошо читается в плотных
  /// списках, где текста много и он мелкий.
  static const fontFamily = 'Nunito Sans';

  /// Заголовки набираются округлым Nunito: он мягче и отделяет заголовок
  /// от текста лучше, чем один только размер.
  static const displayFontFamily = 'Nunito';

  /// Пути, размеры и прочее, что читают глазами по знакам, а не словами.
  static const monoFontFamily = 'JetBrains Mono';

  static ThemeData dark() => _build(EvaporatePalette.dark);

  static ThemeData light() => _build(EvaporatePalette.light);

  static ThemeData _build(EvaporatePalette p) {
    final base = p.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onPrimary,
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerHighest: p.surfaceHigh,
        outline: p.outline,
        error: p.danger,
        onError: p.onPrimary,
      ),
      dividerTheme: DividerThemeData(color: p.outline, space: 1, thickness: 1),
      textTheme: base.textTheme
          .apply(
            bodyColor: p.textPrimary,
            displayColor: p.textPrimary,
            fontFamily: fontFamily,
          )
          .copyWith(
            // Заголовкам — второе семейство: разница в начертании работает
            // там, где разница в размере уже исчерпана.
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            displayMedium: base.textTheme.displayMedium?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            displaySmall: base.textTheme.displaySmall?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: displayFontFamily,
              color: p.textPrimary,
            ),
          ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primary),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.railBackground,
        indicatorColor: p.railIndicator,
        selectedIconTheme: IconThemeData(color: p.onSelection),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textSecondary,
          fontSize: 12,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) &&
                    !states.contains(WidgetState.disabled)
                ? p.selection
                : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) &&
                    !states.contains(WidgetState.disabled)
                ? p.onSelection
                : null,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.outline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: p.outline),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
      ),
    );
  }
}
