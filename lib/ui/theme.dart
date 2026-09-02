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

  /// Тёмная схема — та, с которой приложение начиналось: оно живёт в
  /// полноэкранном окне рядом с играми.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0D1117),
    surface: Color(0xFF151B23),
    surfaceHigh: Color(0xFF1D242E),
    outline: Color(0xFF2A3441),
    primary: Color(0xFF4FC3F7),
    onPrimary: Color(0xFF06202B),
    accent: Color(0xFF7DD3C0),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B98A5),
    railBackground: Color(0xFF10151C),
    railIndicator: Color(0x334FC3F7),
  );

  /// Светлая схема — не осветлённая тёмная.
  ///
  /// Цвета акцентов взяты заметно темнее: голубой и бирюзовый, читаемые на
  /// тёмном фоне, на белом сливаются с ним и не дотягивают до нужного
  /// контраста. За этим следит тест.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEAEFF5),
    outline: Color(0xFFD3DBE4),
    primary: Color(0xFF0E7490),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF127C68),
    danger: Color(0xFFB42318),
    warning: Color(0xFF8A5B00),
    textPrimary: Color(0xFF19212B),
    textSecondary: Color(0xFF56616E),
    railBackground: Color(0xFFEDF1F6),
    railIndicator: Color(0x330E7490),
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
