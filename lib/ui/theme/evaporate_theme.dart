import 'package:flutter/material.dart';

import 'motion.dart';
import 'palette.dart';

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

  /// Собирает тему из палитры. Каждая строка — свой кусок оформления, и
  /// устройство каждого куска лежит в отдельном методе ниже.
  static ThemeData _build(EvaporatePalette p) {
    final base = p.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      extensions: [p, EvaporateMotion.standard],
      scaffoldBackgroundColor: p.background,
      colorScheme: _colorScheme(p),
      dividerTheme: DividerThemeData(color: p.outline, space: 1, thickness: 1),
      textTheme: _textTheme(base.textTheme, p),
      cardTheme: _cardTheme(p),
      inputDecorationTheme: _inputTheme(p),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(p),
      navigationRailTheme: _railTheme(p),
      segmentedButtonTheme: _segmentedButtonTheme(p),
      dialogTheme: _dialogTheme(p),
      snackBarTheme: _snackBarTheme(p),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primaryFill,
        linearTrackColor: p.outline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      tooltipTheme: _tooltipTheme(p),
    );
  }

  static ColorScheme _colorScheme(EvaporatePalette p) => ColorScheme(
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
  );

  /// Заголовкам — второе семейство: разница в начертании работает там, где
  /// разница в размере уже исчерпана. Разряд убывает с размером — крупному
  /// кеглю его нужно меньше.
  static TextTheme _textTheme(TextTheme base, EvaporatePalette p) => base
      .apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
        fontFamily: fontFamily,
      )
      .copyWith(
        displayLarge: _display(base.displayLarge, p, 1.2),
        displayMedium: _display(base.displayMedium, p, 1.0),
        displaySmall: _display(base.displaySmall, p, 0.9),
        headlineLarge: _display(base.headlineLarge, p, 0.8),
        headlineMedium: _display(base.headlineMedium, p, 0.7),
        headlineSmall: _display(base.headlineSmall, p, 0.6),
        titleLarge: _display(base.titleLarge, p, 0.5),
      );

  /// Заголовок: широкое начертание, плотные строки и **положительный**
  /// разряд. У широкого шрифта прижатые друг к другу буквы выглядят
  /// слипшимися, поэтому здесь разряд добавляют, а не убирают.
  static TextStyle? _display(
    TextStyle? from,
    EvaporatePalette p,
    double tracking,
  ) => from?.copyWith(
    fontFamily: displayFontFamily,
    color: p.textPrimary,
    fontWeight: FontWeight.w800,
    height: 1.02,
    letterSpacing: tracking,
  );

  static CardThemeData _cardTheme(EvaporatePalette p) => CardThemeData(
    color: p.surface.withValues(alpha: p.isDark ? 0.82 : 0.9),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusPanel),
      side: BorderSide(color: p.outline.withValues(alpha: 0.62)),
    ),
  );

  static InputDecorationTheme _inputTheme(EvaporatePalette p) {
    OutlineInputBorder border(Color color, [double width = 1.0]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(p.outline),
      enabledBorder: border(p.outline),
      focusedBorder: border(p.primary, 1.5),
      labelStyle: TextStyle(color: p.textSecondary),
      hintStyle: TextStyle(color: p.textSecondary),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
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
  );

  static OutlinedButtonThemeData _outlinedButtonTheme(EvaporatePalette p) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      );

  static NavigationRailThemeData _railTheme(EvaporatePalette p) =>
      NavigationRailThemeData(
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
      );

  /// Выбранный сегмент красится сам; погашенный остаётся как есть, иначе
  /// недоступная кнопка выглядела бы выбранной.
  static SegmentedButtonThemeData _segmentedButtonTheme(EvaporatePalette p) {
    bool chosen(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) &&
        !states.contains(WidgetState.disabled);

    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => chosen(states) ? p.selection : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => chosen(states) ? p.onSelection : null,
        ),
      ),
    );
  }

  static DialogThemeData _dialogTheme(EvaporatePalette p) => DialogThemeData(
    backgroundColor: p.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusPanel),
      side: BorderSide(color: p.outline),
    ),
  );

  static SnackBarThemeData _snackBarTheme(EvaporatePalette p) =>
      SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: BorderSide(color: p.outline),
        ),
      );

  static TooltipThemeData _tooltipTheme(EvaporatePalette p) => TooltipThemeData(
    decoration: BoxDecoration(
      color: p.surfaceHigh,
      borderRadius: BorderRadius.circular(radiusChip),
      border: Border.all(color: p.outline),
    ),
    textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
  );
}
