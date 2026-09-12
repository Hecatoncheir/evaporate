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

  /// Ночная пространственная схема: холодное стекло, ледяной фокус и
  /// мятный цвет успешного состояния. Яркие эффекты библиотеки намеренно
  /// остаются отдельным слоем и не спорят с хромом приложения.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF090D16),
    surface: Color(0xFF141B27),
    surfaceHigh: Color(0xFF202A3A),
    outline: Color(0xFF46556B),
    primary: Color(0xFFA7D8FF),
    onPrimary: Color(0xFF07111C),
    accent: Color(0xFF7FE3C2),
    danger: Color(0xFFFF8B83),
    warning: Color(0xFFFFD166),
    textPrimary: Color(0xFFF7F9FD),
    textSecondary: Color(0xFFB5C0D0),
    railBackground: Color(0xFF0E1420),
    railIndicator: Color(0xFFDCEEFF),
    onSelection: Color(0xFF08121E),
  );

  /// Дневной вариант того же стекла: прохладный туман вместо белого листа,
  /// графитовый текст и глубокие, а не неоновые, функциональные акценты.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFE9EFF7),
    surface: Color(0xFFF9FBFF),
    surfaceHigh: Color(0xFFDFE8F3),
    outline: Color(0xFF8493A8),
    primary: Color(0xFF1767A7),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF00765E),
    danger: Color(0xFFB22B36),
    warning: Color(0xFF785100),
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF475467),
    railBackground: Color(0xFFDCE6F1),
    railIndicator: Color(0xFF173451),
    onSelection: Color(0xFFF8FBFF),
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

  // Портал горит своим огнём, а не цветом темы: он один и тот же на светлой
  // и на тёмной подложке — как искры и должны выглядеть.
  static const portalSpark = Color(0xFFFFE79A);
  static const portalRim = Color(0xFFFF8A1F);
  static const windowCloseForeground = Colors.white;
  static const windowCloseBackground = Color(0xFFC42B1C);

  // Рассеянный свет под стеклянными панелями. Это часть оформления окна,
  // а не семантические цвета текста, поэтому значения общие для темы.
  static const ambientBlue = Color(0xFF2B6FA8);
  static const ambientViolet = Color(0xFF684C9E);
  static const ambientMint = Color(0xFF2F8D7A);
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
