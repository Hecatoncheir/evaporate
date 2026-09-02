import 'package:flutter/material.dart';

/// Цвета приложения.
///
/// Раздаются через тему, а не константами: иначе светлая и тёмная схемы
/// не могли бы существовать одновременно. Берутся из контекста —
/// `context.colors.textSecondary`.
class EvaporatePalette extends ThemeExtension<EvaporatePalette> {
  const EvaporatePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.railBackground,
    required this.railIndicator,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color primary;

  /// Что пишут поверх [primary] — на светлой и тёмной это разные концы шкалы.
  final Color onPrimary;
  final Color accent;
  final Color danger;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color railBackground;
  final Color railIndicator;

  bool get isDark => brightness == Brightness.dark;

  /// Тёмная схема на палитре FFFCF2 / CCC5B9 / 403D39 / 252422 / EB5E28.
  ///
  /// Четыре цвета из пяти взяты как есть. Акцент осветлён на четыре процента
  /// светлоты — тон и насыщенность те же: в исходном виде EB5E28 не дотягивал
  /// до порога читаемости на подложке карточек, а им набрана метка статуса,
  /// не только рамка. Сделать подложку темнее не вышло бы: она сравнялась бы
  /// с фоном, и карточки перестали бы читаться как карточки.
  ///
  /// Хроматический цвет в палитре один, поэтому «запущена», «ошибка» и
  /// «внимание» разведены поворотом тона от него же — семейство остаётся
  /// тёплым, а состояния различаются.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF252422),
    surface: Color(0xFF2E2C2A),
    surfaceHigh: Color(0xFF403D39),
    outline: Color(0xFF4B4740),
    primary: Color(0xFFED6C3B),
    onPrimary: Color(0xFF1A1815),
    accent: Color(0xFFE8A87C),
    danger: Color(0xFFF2685A),
    warning: Color(0xFFDFAE4E),
    textPrimary: Color(0xFFFFFCF2),
    textSecondary: Color(0xFFCCC5B9),
    railBackground: Color(0xFF1F1E1C),
    railIndicator: Color(0x33ED6C3B),
  );

  /// Светлая схема на палитре 264653 / 2A9D8F / E9C46A / F4A261 / E76F51.
  ///
  /// Тёмно-бирюзовый взят как есть — он отлично читается как текст. А вот
  /// светлого фона в палитре нет вовсе, поэтому подложки выведены как очень
  /// светлые оттенки того же тона.
  ///
  /// Три тёплых цвета затемнены, и заметно. В исходном виде это цвета для
  /// заливок, а не для подписей: песочный E9C46A даёт на светлом фоне 1.5 при
  /// нужных 4.5 — втрое меньше нормы. Тон и насыщенность сохранены, так что
  /// палитра узнаётся, но подписи ими теперь можно набирать.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F6F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE3EDEE),
    outline: Color(0xFFC2D2D6),
    primary: Color(0xFF217D72),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB2560C),
    danger: Color(0xFFC44020),
    warning: Color(0xFF8E6B15),
    textPrimary: Color(0xFF264653),
    textSecondary: Color(0xFF4F6B75),
    railBackground: Color(0xFFE7EFF0),
    railIndicator: Color(0x33217D72),
  );

  @override
  EvaporatePalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? danger,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
    Color? railBackground,
    Color? railIndicator,
  }) {
    return EvaporatePalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      railBackground: railBackground ?? this.railBackground,
      railIndicator: railIndicator ?? this.railIndicator,
    );
  }

  @override
  EvaporatePalette lerp(ThemeExtension<EvaporatePalette>? other, double t) {
    if (other is! EvaporatePalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return EvaporatePalette(
      // Яркость не смешивается: она переключается разом на середине.
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      outline: mix(outline, other.outline),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      railBackground: mix(railBackground, other.railBackground),
      railIndicator: mix(railIndicator, other.railIndicator),
    );
  }
}

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
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
        selectedIconTheme: IconThemeData(color: p.primary),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: p.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 12,
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
