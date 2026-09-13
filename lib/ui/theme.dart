import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'motion.dart';
export 'app_colors.dart';
export 'motion.dart';

/// Короткий доступ к палитре: `context.colors.textSecondary`.
extension EvaporateColors on BuildContext {
  EvaporatePalette get colors =>
      Theme.of(this).extension<EvaporatePalette>() ?? EvaporatePalette.dark;
}

/// Темы приложения.
class EvaporateTheme {
  const EvaporateTheme._();

  /// Основной шрифт интерфейса. Golos Text рисовали под кириллицу, а не
  /// добавляли её позже: в плотных списках с путями и названиями игр это
  /// видно сразу — у латиницы и кириллицы одинаковый ритм.
  static const fontFamily = 'Golos Text';

  /// Заголовки и главные клавиши. Unbounded широкий и геометричный: он
  /// звучит как надпись на корпусе, а не как текст абзаца, и поэтому
  /// отделяет заголовок от содержимого сильнее, чем один только размер.
  static const displayFontFamily = 'Unbounded';

  /// Пути, размеры и прочее, что читают глазами по знакам, а не словами.
  static const monoFontFamily = 'JetBrains Mono';

  /// Геометрия корпуса. Радиусы малые и одни на обе схемы: округлость —
  /// это про яркость не больше, чем толщина рамки, и разные углы в двух
  /// темах читались бы как два разных приложения.
  static const radiusShell = 8.0;
  static const radiusPanel = 6.0;
  static const radiusControl = 4.0;
  static const radiusChip = 3.0;

  /// Скругление подложки под выбранным.
  ///
  /// К четырём корпусным радиусам выше не относится и нарочно крупнее их:
  /// те малые, потому что описывают корпус — панели, клавиши, плашки. Этот
  /// у подложки, которая обнимает одну клавишу и больше ничего, и
  /// корпусной угол на ней читался бы обрезанным краем панели, а не фоном
  /// под выбранным.
  static const radiusSelection = 12.0;

  static ThemeData dark() => _build(EvaporatePalette.dark);

  static ThemeData light() => _build(EvaporatePalette.light);

  static ThemeData _build(EvaporatePalette p) {
    final base = p.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    /// Заголовок: широкое начертание, плотные строки и **положительный**
    /// разряд. У широкого шрифта прижатые друг к другу буквы выглядят
    /// слипшимися, поэтому здесь разряд добавляют, а не убирают.
    TextStyle? display(TextStyle? from, double tracking) => from?.copyWith(
      fontFamily: displayFontFamily,
      color: p.textPrimary,
      fontWeight: FontWeight.w800,
      height: 1.02,
      letterSpacing: tracking,
    );

    return base.copyWith(
      extensions: [p, EvaporateMotion.standard],
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        // В схему уходит заливочный цвет: Material красит им фон кнопки,
        // а не набирает им текст.
        primary: p.primaryFill,
        onPrimary: p.onPrimary,
        secondary: p.accentFill,
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
            // там, где разница в размере уже исчерпана. Разряд убывает с
            // размером — крупному кеглю его нужно меньше.
            displayLarge: display(base.textTheme.displayLarge, 1.2),
            displayMedium: display(base.textTheme.displayMedium, 1.0),
            displaySmall: display(base.textTheme.displaySmall, 0.9),
            headlineLarge: display(base.textTheme.headlineLarge, 0.8),
            headlineMedium: display(base.textTheme.headlineMedium, 0.7),
            headlineSmall: display(base.textTheme.headlineSmall, 0.6),
            titleLarge: display(base.textTheme.titleLarge, 0.5),
          ),
      cardTheme: CardThemeData(
        color: p.surface.withValues(alpha: p.isDark ? 0.82 : 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: BorderSide(color: p.outline.withValues(alpha: 0.62)),
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
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(
            fontFamily: displayFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
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
          borderRadius: BorderRadius.circular(radiusPanel),
          side: BorderSide(color: p.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: BorderSide(color: p.outline),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primaryFill,
        linearTrackColor: p.outline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(radiusChip),
          border: Border.all(color: p.outline),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
      ),
    );
  }
}
