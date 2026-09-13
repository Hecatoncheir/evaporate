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

  /// Ночная схема напоминает дисплей музыкального устройства: почти чёрный
  /// графит, тёплая подсветка органов управления и холодный служебный сигнал.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B0D0E),
    surface: Color(0xFF17191A),
    surfaceHigh: Color(0xFF292C2D),
    outline: Color(0xFF5D6263),
    primary: Color(0xFFFF6842),
    onPrimary: Color(0xFF240A03),
    accent: Color(0xFF6AC9DE),
    danger: Color(0xFFFF9184),
    warning: Color(0xFFFFC65A),
    textPrimary: Color(0xFFF5F3ED),
    textSecondary: Color(0xFFBEC1BE),
    railBackground: Color(0xFF111314),
    railIndicator: Color(0xFFF0EEE8),
    onSelection: Color(0xFF17191A),
  );

  /// Дневная схема собрана как тёплый алюминиевый корпус: поверхности хорошо
  /// отделены глубиной, а оранжевый остаётся единственным главным действием.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFDDDCD7),
    surface: Color(0xFFF2F0EA),
    surfaceHigh: Color(0xFFD0D2D0),
    outline: Color(0xFF797E7F),
    primary: Color(0xFFB82508),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF005F73),
    danger: Color(0xFFAD2430),
    warning: Color(0xFF765000),
    textPrimary: Color(0xFF17191A),
    textSecondary: Color(0xFF4F5455),
    railBackground: Color(0xFFC9CCCA),
    railIndicator: Color(0xFF202324),
    onSelection: Color(0xFFF7F5EF),
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

/// Насыщенные цвета — декоративные. Текст ими не красят: для него есть
/// цвета темы, выверенные по контрасту в `theme_test.dart`.
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

/// Цвета, не зависящие от темы: оформление обложек, эффекты и рамка окна.
/// Здесь лежат базовые значения; прозрачность виджеты всё ещё анимируют.
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
  static const heroShadeStrong = Color(0xED090B0C);
  static const heroShadeMiddle = Color(0x70090B0C);
  static const heroShadeClear = Color(0x08090B0C);
  static const heroEyebrow = Color(0xFFFF8158);
  static const heroBody = Color(0xFFD7D9D6);
  static const heroPanel = Color(0xC9181A1B);
  static const launcherGreenTop = Color(0xFF91C438);
  static const launcherGreenBottom = Color(0xFF5F9517);
  static const launcherGreenBorder = Color(0xFF436F0E);
  static const launcherButtonText = Colors.white;
  static const frostDark = Color(0xB80B0D0E);
  static const frostLight = Color(0x9EF2F0EA);

  // Портал горит своим огнём, а не цветом темы: он один и тот же на светлой
  // и на тёмной подложке — как искры и должны выглядеть.
  static const portalSpark = Color(0xFFFFE79A);
  static const portalRim = Color(0xFFFF8A1F);
  static const windowCloseForeground = Colors.white;
  static const windowCloseBackground = Color(0xFFC42B1C);

  // Рассеянный свет и металл под панелями. Это часть оформления корпуса,
  // а не семантические цвета текста, поэтому значения общие для темы.
  static const ambientOrange = Color(0xFFF04A22);
  static const ambientSteel = Color(0xFF8E9698);
  static const ambientCharcoal = Color(0xFF16191A);
  static final hardwareShadowDark = Colors.black.withValues(alpha: 0.48);
  static final hardwareShadowLight = const Color(0xFF777B7A)
      .withValues(alpha: 0.3);
  static final grilleHoleDark = Colors.black.withValues(alpha: 0.72);
  static final grilleHoleLight = const Color(0xFF333738)
      .withValues(alpha: 0.76);
}

const _darkWaveColors = [
  Color(0xFFF2685A),
  Color(0xFFDFAE4E),
  Color(0xFF05BDC9),
  Color(0xFFCCC5B9),
];
const _lightWaveColors = [
  Color(0xFFAD175E),
  Color(0xFFF2685A),
  Color(0xFF05BDC9),
  Color(0xFFB62D38),
];

List<Color> waveColors(bool isDark) =>
    isDark ? _darkWaveColors : _lightWaveColors;

/// Запасные цвета обложки, выведенные из названия игры.
///
/// Устойчивы и не зависят от темы: игра без обложки должна выглядеть
/// одинаково от запуска к запуску, иначе библиотека каждый раз чужая.
List<Color> gameCoverColors(String title) {
  final hue = (title.hashCode % 360).abs().toDouble();
  return [
    HSLColor.fromAHSL(1, hue, 0.32, 0.27).toColor(),
    HSLColor.fromAHSL(1, (hue + 24) % 360, 0.30, 0.13).toColor(),
  ];
}
