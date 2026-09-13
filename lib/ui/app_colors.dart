import 'package:flutter/material.dart';

/// Цвета приложения.
///
/// Раздаются через тему, а не константами: иначе светлая и тёмная схемы
/// не могли бы существовать одновременно. Берутся из контекста —
/// `context.colors.textSecondary`.
///
/// Две схемы — это два самостоятельных облика, а не одна палитра с
/// вывернутой яркостью. «Арклайт» (ночь) — чернильный корпус кинозала с
/// тёплым золотом; «Картридж» (день) — светлый корпус измерительного
/// прибора с плоским насыщенным цветом. Осветлённая копия ночной схемы
/// выглядела бы выцветшей, и обратно — тоже.
class EvaporatePalette extends ThemeExtension<EvaporatePalette> {
  const EvaporatePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.primary,
    required this.primaryFill,
    required this.onPrimary,
    required this.accent,
    required this.accentFill,
    required this.danger,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.railBackground,
    required this.railIndicator,
    required this.onSelection,
    required this.glow,
    required this.depth,
    required this.shadow,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;

  /// Фирменный цвет **для текста и значков**: им набраны надстрочные метки,
  /// проценты и состояния, поэтому он проверен по контрасту на подложках.
  final Color primary;

  /// Тот же цвет **для заливок**. Роли разделены не для красоты: насыщенный
  /// оранжевый Картриджа хорош как блок под надписью и не дотягивает до
  /// нормы как текст на светлом фоне. Один токен на две роли означал бы
  /// либо тусклые кнопки, либо нечитаемые подписи.
  final Color primaryFill;

  /// Что пишут поверх [primaryFill].
  final Color onPrimary;

  /// Служебный акцент для текста (скорости, ссылки, «готово»).
  final Color accent;

  /// Он же для заливок и светодиодов, где яркость важнее читаемости.
  final Color accentFill;
  final Color danger;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color railBackground;
  final Color railIndicator;
  final Color onSelection;

  /// Ореол вокруг активного: в ночной схеме светится золото, в дневной
  /// **прозрачный** — светлый корпус не светится, он отбрасывает тень.
  final Color glow;

  /// «Толщина» под клавишей: в дневной схеме кнопка стоит на своём тёмном
  /// торце и проваливается при нажатии, в ночной торца нет.
  final Color depth;

  /// Тень панелей: в ночи длинная и мягкая, днём короткая и жёсткая.
  final Color shadow;

  Color get selection => railIndicator;

  bool get isDark => brightness == Brightness.dark;

  /// «Арклайт»: почти чёрные чернила, тёплое золото главного действия и
  /// холодный сигнальный голубой на показаниях. Цвет в интерфейс приносят
  /// обложки игр, поэтому сам корпус остаётся сдержанным.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF06080B),
    surface: Color(0xFF0D1116),
    surfaceHigh: Color(0xFF18202A),
    outline: Color(0xFF26303B),
    primary: Color(0xFFE9C877),
    primaryFill: Color(0xFFE9C877),
    onPrimary: Color(0xFF0A0D11),
    accent: Color(0xFF49B7E0),
    accentFill: Color(0xFF49B7E0),
    danger: Color(0xFFE96A5C),
    warning: Color(0xFFF2A93B),
    textPrimary: Color(0xFFECE6D8),
    textSecondary: Color(0xFF9BA6B2),
    railBackground: Color(0xFF080B0F),
    railIndicator: Color(0xFFE9C877),
    onSelection: Color(0xFF0A0D11),
    glow: Color(0xFFE9C877),
    depth: Color(0x00000000),
    shadow: Color(0xB3000000),
  );

  /// «Картридж»: светлый корпус, плоский цвет без переходов и чёрные
  /// надписи на оранжевом — так подписывают органы управления на железе.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFE4E1D8),
    surface: Color(0xFFF7F6F2),
    surfaceHigh: Color(0xFFD8D5CA),
    outline: Color(0xFFBCB7A9),
    primary: Color(0xFFA62C00),
    primaryFill: Color(0xFFFF4A17),
    onPrimary: Color(0xFF1F0800),
    accent: Color(0xFF006472),
    accentFill: Color(0xFF0090A8),
    danger: Color(0xFFA8231B),
    warning: Color(0xFF7A5200),
    textPrimary: Color(0xFF16171A),
    textSecondary: Color(0xFF55585C),
    railBackground: Color(0xFFDAD7CD),
    railIndicator: Color(0xFF16171A),
    onSelection: Color(0xFFF7F6F2),
    glow: Color(0x00000000),
    depth: Color(0xFFB22F08),
    shadow: Color(0x33000000),
  );

  @override
  EvaporatePalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? primary,
    Color? primaryFill,
    Color? onPrimary,
    Color? accent,
    Color? accentFill,
    Color? danger,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
    Color? railBackground,
    Color? railIndicator,
    Color? onSelection,
    Color? glow,
    Color? depth,
    Color? shadow,
  }) {
    return EvaporatePalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      primaryFill: primaryFill ?? this.primaryFill,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentFill: accentFill ?? this.accentFill,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      railBackground: railBackground ?? this.railBackground,
      railIndicator: railIndicator ?? this.railIndicator,
      onSelection: onSelection ?? this.onSelection,
      glow: glow ?? this.glow,
      depth: depth ?? this.depth,
      shadow: shadow ?? this.shadow,
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
      primaryFill: mix(primaryFill, other.primaryFill),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      accentFill: mix(accentFill, other.accentFill),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      railBackground: mix(railBackground, other.railBackground),
      railIndicator: mix(railIndicator, other.railIndicator),
      onSelection: mix(onSelection, other.onSelection),
      glow: mix(glow, other.glow),
      depth: mix(depth, other.depth),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// Насыщенные цвета — декоративные. Текст ими не красят: для него есть
/// цвета темы, выверенные по контрасту в `theme_test.dart`.
///
/// Набор собран вокруг ночной схемы: золото, сигнальный голубой и коралл —
/// те же три голоса, что и у корпуса, только в полную силу.
const libraryInkColors = [
  Color(0xFFF2C368),
  Color(0xFF49B7E0),
  Color(0xFFE0574A),
  Color(0xFFF2A93B),
  Color(0xFF9A7BD8),
  Color(0xFFF2C368),
];

Color ambientParticleColor(bool isDark) =>
    isDark ? const Color(0xFFE9C877) : const Color(0xFF8C3A10);

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

  /// Непрозрачное для масок: в `BlendMode.dstIn` важна одна альфа, а не
  /// цвет, — но писать `Colors.white` там, где речь о непрозрачности,
  /// значит заставлять читателя гадать, при чём тут белый.
  static const opaque = Colors.white;
  static const coverText = Colors.white;
  static const coverTextShadow = Colors.black54;
  static final coverShadow = Colors.black.withValues(alpha: 0.3);
  static final coverOverlay = Colors.black.withValues(alpha: 0.66);
  static final detailOverlay = Colors.black.withValues(alpha: 0.62);
  static const coverProgressTrack = Colors.white24;
  static const foilHighlight = Colors.white;
  static const waveHighlight = Colors.white;

  // Затемнение поверх обложки героя: три ступени одного чернильного цвета,
  // чтобы надпись читалась на любой картинке, а верх кадра остался виден.
  static const heroShadeStrong = Color(0xED06080B);
  static const heroShadeMiddle = Color(0x7006080B);
  static const heroShadeClear = Color(0x0806080B);
  static const heroEyebrow = Color(0xFFE9C877);
  static const heroBody = Color(0xFFB9C0C8);
  static const heroPanel = Color(0xC90D1116);

  /// Полоса света, проходящая по герою. Единственное, что двигается по
  /// обложке само: она и отличает живой кадр от вклеенной картинки.
  static final artSweep = Colors.white.withValues(alpha: 0.09);

  static const frostDark = Color(0xB306080B);
  static const frostLight = Color(0x9EF7F6F2);

  // Портал горит своим огнём, а не цветом темы: он один и тот же на светлой
  // и на тёмной подложке — как искры и должны выглядеть.
  static const portalSpark = Color(0xFFFFE79A);
  static const portalRim = Color(0xFFFF8A1F);
  static const windowCloseForeground = Colors.white;
  static const windowCloseBackground = Color(0xFFC42B1C);

  // Рассеянный свет и металл под панелями. Это часть оформления корпуса,
  // а не семантические цвета текста, поэтому значения общие для темы.
  static const ambientWarm = Color(0xFFE9C877);
  static const ambientCool = Color(0xFF49B7E0);
  static const ambientDeep = Color(0xFF0D1116);
  static final hardwareShadowDark = Colors.black.withValues(alpha: 0.55);
  static final hardwareShadowLight = const Color(0xFF8A8574)
      .withValues(alpha: 0.34);
  static final grilleHoleDark = Colors.black.withValues(alpha: 0.72);
  static final grilleHoleLight = const Color(0xFF333738)
      .withValues(alpha: 0.76);
}

const _darkWaveColors = [
  Color(0xFFE9C877),
  Color(0xFF49B7E0),
  Color(0xFFE0574A),
  Color(0xFFC9C2B2),
];
const _lightWaveColors = [
  Color(0xFFFF4A17),
  Color(0xFFFFC400),
  Color(0xFF0090A8),
  Color(0xFFB3261E),
];

List<Color> waveColors(bool isDark) =>
    isDark ? _darkWaveColors : _lightWaveColors;

/// Запасные цвета обложки, выведенные из названия игры.
///
/// Устойчивы и не зависят от темы: игра без обложки должна выглядеть
/// одинаково от запуска к запуску, иначе библиотека каждый раз чужая.
List<Color> gameCoverColors(String title) {
  final hue = _titleHue(title);
  return [
    HSLColor.fromAHSL(1, hue, 0.34, 0.30).toColor(),
    HSLColor.fromAHSL(1, (hue + 24) % 360, 0.32, 0.13).toColor(),
  ];
}

/// Оттенки, которыми игра может подсветить корпус.
///
/// Набор выверенный, а не весь круг: свободный оттенок от хеша названия
/// рано или поздно выдаёт болотно-зелёный или грязно-жёлтый, и оболочка
/// выглядит не «своей у каждого», а сломанной. Шесть якорей — киноварь,
/// янтарь, изумруд, лазурь, индиго и фуксия — все живут рядом с золотом
/// корпуса и ни один не спорит с ним.
const ambientHues = [8.0, 36.0, 152.0, 202.0, 258.0, 322.0];

/// Свет, которым игра заливает корпус, пока она выбрана.
///
/// Взят от названия, а не от пикселей обложки: разбор картинки означал бы
/// её декодирование на каждую перелистку, а разница на глаз невелика —
/// свет всё равно размыт до пятна. Зато цвет не меняется от запуска к
/// запуску: игра всегда светит одним и тем же.
List<Color> gameAmbientColors(String title) {
  final hash = title.hashCode.abs();
  // Небольшой разброс внутри якоря: две игры одного семейства оттенков
  // всё-таки светят по-разному.
  final hue =
      (ambientHues[hash % ambientHues.length] + (hash ~/ 7) % 13 - 6 + 360) %
      360;
  return [
    HSLColor.fromAHSL(1, hue, 0.70, 0.50).toColor(),
    HSLColor.fromAHSL(1, (hue + 28) % 360, 0.64, 0.42).toColor(),
    HSLColor.fromAHSL(1, (hue + 320) % 360, 0.56, 0.24).toColor(),
  ];
}

double _titleHue(String title) => (title.hashCode % 360).abs().toDouble();
