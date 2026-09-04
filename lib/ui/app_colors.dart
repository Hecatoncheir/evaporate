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
    required this.onSelection,
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
  final Color onSelection;
  Color get selection => railIndicator;

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
    railIndicator: Color(0xFFE8E1CF),
    onSelection: Color(0xFF201B31),
  );

  /// Бумажный кремовый фон и чернильный индиго из иконки. Яркие краски
  /// используются в декоративном слое; их текстовые варианты затемнены
  /// до контраста WCAG, чтобы переливы не мешали чтению.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFF7EFDD),
    surface: Color(0xFFFFFAEF),
    surfaceHigh: Color(0xFFF0E4D3),
    outline: Color(0xFFCABBD0),
    primary: Color(0xFFAD175E),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF006E78),
    danger: Color(0xFFB62D38),
    warning: Color(0xFF805600),
    textPrimary: Color(0xFF19162F),
    textSecondary: Color(0xFF62566D),
    railBackground: Color(0xFFF1E5D3),
    railIndicator: Color(0xFF201B31),
    onSelection: Color(0xFFE8E1CF),
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
    Color? onSelection,
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
      onSelection: onSelection ?? this.onSelection,
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
      onSelection: mix(onSelection, other.onSelection),
    );
  }
}

/// Saturated ink is decorative; text uses the contrast-tested theme colors.
const libraryInkColors = [
  Color(0xFFEF147C),
  Color(0xFFFF713F),
  Color(0xFFFFC52E),
  Color(0xFF05BDC9),
  Color(0xFF7552D9),
  Color(0xFFEF147C),
];

Color ambientParticleColor(bool isDark) =>
    isDark ? const Color(0xFFF2685A) : const Color(0xFF2F0346);

Color particleColor({
  required bool isDark,
  required double phase,
  required double glow,
}) => Color.lerp(
  ambientParticleColor(isDark),
  libraryInkColors[(phase * 10).floor() % 5],
  glow,
)!;

/// Theme-independent colours used by artwork, effects and window chrome.
/// Base colours live here; widgets may still animate their opacity.
abstract final class AppColors {
  static const transparent = Colors.transparent;
  static const coverText = Colors.white;
  static const coverTextShadow = Colors.black54;
  static final coverShadow = Colors.black.withValues(alpha: 0.3);
  static final coverOverlay = Colors.black.withValues(alpha: 0.66);
  static final detailOverlay = Colors.black.withValues(alpha: 0.62);
  static const coverProgressTrack = Colors.white24;
  static const foilHighlight = Colors.white;
  static const waveHighlight = Colors.white;
  static const windowCloseForeground = Colors.white;
  static const windowCloseBackground = Color(0xFFC42B1C);
}

const _darkWaveColors = [
  Color(0xFF00E9F0),
  Color(0xFF4D7CFF),
  Color(0xFFA855F7),
  Color(0xFFFF2E93),
];
const _lightWaveColors = [
  Color(0xFF00878B),
  Color(0xFF4664C0),
  Color(0xFF8041AC),
  Color(0xFFB6196A),
];

List<Color> waveColors(bool isDark) =>
    isDark ? _darkWaveColors : _lightWaveColors;

/// Stable, title-derived fallback artwork colours, independent of UI theme.
List<Color> gameCoverColors(String title) {
  final hue = (title.hashCode % 360).abs().toDouble();
  return [
    HSLColor.fromAHSL(1, hue, 0.32, 0.27).toColor(),
    HSLColor.fromAHSL(1, (hue + 24) % 360, 0.30, 0.13).toColor(),
  ];
}
