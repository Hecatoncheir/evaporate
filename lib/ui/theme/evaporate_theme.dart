import 'package:flutter/material.dart';

import 'alpha.dart';
import 'effects_palette.dart';
import 'glass_surface_theme.dart';
import 'hardware_surface_theme.dart';
import 'icon_size.dart';
import 'launcher_button_theme.dart';
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
  ///
  /// Числа — плотный набор прототипа (`docs/decisions/0010`). Угол панели
  /// режет и обложку, и он же — скругление кромки, по которой рождаются
  /// искры (`PortalOutline.corner`): разойдись они, между вырезом и искрами
  /// в углу оставался бы тёмный шов.
  static const radiusPanel = 8.0;
  static const radiusControl = 5.0;
  static const radiusChip = 3.0;

  /// Скругление подложки под выбранным.
  ///
  /// К четырём корпусным радиусам выше не относится и нарочно крупнее их:
  /// те малые, потому что описывают корпус — панели, клавиши, плашки. Этот
  /// у подложки, которая обнимает одну клавишу и больше ничего, и
  /// корпусной угол на ней читался бы обрезанным краем панели, а не фоном
  /// под выбранным.
  static const radiusSelection = 12.0;

  static ThemeData dark() => _build(
    EvaporatePalette.dark,
    HardwareSurfaceTheme.arclight,
    GlassSurfaceTheme.arclight,
    EffectsPalette.arclight,
    LauncherButtonTheme.arclight,
  );

  static ThemeData light() => _build(
    EvaporatePalette.light,
    HardwareSurfaceTheme.cartridge,
    GlassSurfaceTheme.cartridge,
    EffectsPalette.cartridge,
    LauncherButtonTheme.cartridge,
  );

  /// Собирает тему из палитры. Каждая строка — свой кусок оформления, и
  /// устройство каждого куска лежит в отдельном методе ниже.
  static ThemeData _build(
    EvaporatePalette p,
    HardwareSurfaceTheme surface,
    GlassSurfaceTheme glass,
    EffectsPalette effects,
    LauncherButtonTheme launcher,
  ) {
    final base = p.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      extensions: [
        p,
        EvaporateMotion.standard,
        surface,
        glass,
        effects,
        launcher,
      ],
      scaffoldBackgroundColor: p.background,
      colorScheme: _colorScheme(p),
      dividerTheme: DividerThemeData(color: p.outline, space: 1, thickness: 1),
      textTheme: _textTheme(base.textTheme, p),
      cardTheme: _cardTheme(p, surface),
      inputDecorationTheme: _inputTheme(p),
      filledButtonTheme: _filledButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      iconButtonTheme: _iconButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(p),
      segmentedButtonTheme: _segmentedButtonTheme(p),
      dialogTheme: _dialogTheme(p),
      snackBarTheme: _snackBarTheme(p),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primaryFill,
        linearTrackColor: p.outline,
      ),
      // Все списки приложения плотные: плотная раскладка ListTile сама даёт
      // кегли 13 и 12, и повторять `dense` и кегль в каждой строке незачем.
      listTileTheme: ListTileThemeData(
        dense: true,
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      tooltipTheme: _tooltipTheme(p),
      scrollbarTheme: _scrollbarTheme(p),
      textSelectionTheme: _textSelectionTheme(p),
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

  static CardThemeData _cardTheme(
    EvaporatePalette p,
    HardwareSurfaceTheme surface,
  ) => CardThemeData(
    color: p.surface.withValues(alpha: surface.materialCardOpacity),
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

  // Значок на клавише — ступень `key` у всех четырёх видов клавиш: прежде
  // размер выписывался у каждого значка по месту (16, а где и 17), а
  // забытый давал материаловские 18.
  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      iconSize: EvaporateIconSize.key,
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

  // Угол текстовой клавиши и клавиши-значка — корпусный, как у залитой: по
  // умолчанию Material скругляет их в капсулу и круг, и подложка при
  // наведении выглядела чужой. Прежде угол выписывали по месту.
  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
    style: TextButton.styleFrom(
      iconSize: EvaporateIconSize.key,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusControl),
      ),
    ),
  );

  static IconButtonThemeData _iconButtonTheme() => IconButtonThemeData(
    style: IconButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusControl),
      ),
    ),
  );

  static OutlinedButtonThemeData _outlinedButtonTheme(EvaporatePalette p) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          iconSize: EvaporateIconSize.key,
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
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
        // Кегль сегментов один на все переключатели: прежде он был выписан
        // по месту четырежды, а два переключателя его не задавали вовсе.
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontFamily: fontFamily),
        ),
        iconSize: const WidgetStatePropertyAll(EvaporateIconSize.key),
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

  /// Полоса прокрутки тоньше материаловской и цвета границ: она показывает,
  /// где ты в списке, а не спорит с ним. Под курсором и при перетаскивании
  /// толще и заметнее — за неё взялись.
  static ScrollbarThemeData _scrollbarTheme(EvaporatePalette p) {
    bool held(Set<WidgetState> states) =>
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.dragged);

    return ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith(
        (states) => held(states) ? 9 : 6,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => held(states)
            ? p.textSecondary.withValues(alpha: EvaporateAlpha.rim)
            : p.outline,
      ),
      radius: const Radius.circular(radiusPanel),
    );
  }

  /// Выделенный текст — подкраска фирменного цвета, курсор и ручки — цвета
  /// выбора: так выделение читается тем же жестом, что выбор в сетке.
  static TextSelectionThemeData _textSelectionTheme(EvaporatePalette p) =>
      TextSelectionThemeData(
        cursorColor: p.selection,
        selectionColor: p.primaryFill.withValues(alpha: 0.32),
        selectionHandleColor: p.selection,
      );
}
