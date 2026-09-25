import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Из какой ступени поверхности взята заливка стекла.
enum EvGlassTint {
  /// Земля окна — самое тёмное стекло, для линз поверх картинки.
  ground,

  /// Подложка героя.
  sub,

  /// Панели и полосы каркаса.
  surface,

  /// Поповеры: палитра, подсказки.
  raised;

  Color of(EvColors c) => switch (this) {
    EvGlassTint.ground => c.ground,
    EvGlassTint.sub => c.sub,
    EvGlassTint.surface => c.surface,
    EvGlassTint.raised => c.raised,
  };
}

/// Материал стекла: сколько оно берёт от фона и сколько отдаёт свету.
///
/// Материалов два, как в iOS: **иней** — толстое матовое стекло
/// навигационного слоя, сквозь него фон читается только светом и цветом;
/// **линза** — прозрачное стекло поверх картинки, оно почти не размывает,
/// зато гнёт фон у кромки.
///
/// Всё, что здесь в пикселях, — логические пиксели.
@immutable
class EvGlassStyle {
  const EvGlassStyle({
    required this.blur,
    required this.saturation,
    required this.brightness,
    required this.tint,
    required this.tintAlpha,
    required this.rimKey,
    required this.rimAmbient,
    required this.rimBack,
    required this.sheen,
    required this.glow,
    required this.bevel,
    required this.depth,
    required this.dispersion,
    required this.grain,
  });

  /// Размытие фона под стеклом, σ.
  final double blur;

  /// Насыщенность фона: 1 — как есть. Стекло собирает цвет, поэтому
  /// под ним фон насыщеннее, чем рядом.
  final double saturation;

  /// Яркость фона под стеклом. Меньше единицы — стекло притеняет,
  /// иначе текст на нём не удержит контраст.
  final double brightness;

  /// Ступень поверхности для заливки.
  final EvGlassTint tint;

  /// Плотность заливки.
  final double tintAlpha;

  /// Блик на кромке со стороны света.
  final double rimKey;

  /// Свет, который есть у кромки всегда, — иначе стекло пропадает,
  /// когда курсор далеко.
  final double rimAmbient;

  /// Блик на дальней кромке: свет выходит из стекла с другой стороны.
  final double rimBack;

  /// Внутреннее свечение от освещённой кромки вглубь.
  final double sheen;

  /// Свечение под курсором: стекло загорается изнутри там, где его трогают.
  final double glow;

  /// Ширина кромки, на которой фон преломляется. 0 — стекло без линзы.
  final double bevel;

  /// Наибольший сдвиг фона у самого края.
  final double depth;

  /// Расхождение каналов на сдвиге — дисперсия в стекле.
  final double dispersion;

  /// Плёночное зерно поверх заливки: снимает бандинг на размытии.
  final bool grain;

  /// Иней: рейл, полосы каркаса, панели, палитра, подсказки.
  static const frost = EvGlassStyle(
    blur: 22,
    saturation: 1.6,
    brightness: 0.68,
    tint: EvGlassTint.surface,
    tintAlpha: 0.62,
    rimKey: 0.4,
    rimAmbient: 0.09,
    rimBack: 0.13,
    sheen: 0.035,
    glow: 0.05,
    bevel: 0,
    depth: 0,
    dispersion: 0,
    grain: true,
  );

  /// Иней поверх затемнения: палитра команд и поповеры лежат на своём
  /// затемнении, поэтому берут больше заливки и меньше размытия.
  static const raised = EvGlassStyle(
    blur: 30,
    saturation: 1.35,
    brightness: 0.8,
    tint: EvGlassTint.raised,
    tintAlpha: 0.72,
    rimKey: 0.3,
    rimAmbient: 0.1,
    rimBack: 0.12,
    sheen: 0.03,
    glow: 0.05,
    bevel: 0,
    depth: 0,
    dispersion: 0,
    grain: true,
  );

  /// Линза: чипы, второстепенные кнопки, бейджи — всё, что лежит
  /// поверх картинки и должно её показывать, а не прятать.
  static const lens = EvGlassStyle(
    blur: 6,
    saturation: 1.35,
    brightness: 0.92,
    tint: EvGlassTint.sub,
    tintAlpha: 0.42,
    rimKey: 0.62,
    rimAmbient: 0.14,
    rimBack: 0.22,
    sheen: 0.06,
    glow: 0.09,
    bevel: 13,
    depth: 8,
    dispersion: 0.25,
    grain: false,
  );

  /// Капля выбора: та же линза без фона, но свет на кромке мягче —
  /// капля помечает выбранное, а не спорит с ним за внимание.
  static const droplet = EvGlassStyle(
    blur: 0,
    saturation: 1,
    brightness: 1,
    tint: EvGlassTint.ground,
    tintAlpha: 0.22,
    rimKey: 0.22,
    rimAmbient: 0.07,
    rimBack: 0.1,
    sheen: 0.05,
    glow: 0,
    bevel: 0,
    depth: 0,
    dispersion: 0,
    grain: false,
  );

  /// Линза без фона: мелочь поверх другого стекла — клавиши, кнопки
  /// в полосе. Читать фон второй раз незачем.
  static const chip = EvGlassStyle(
    blur: 0,
    saturation: 1,
    brightness: 1,
    tint: EvGlassTint.ground,
    tintAlpha: 0.22,
    rimKey: 0.42,
    rimAmbient: 0.12,
    rimBack: 0.18,
    sheen: 0.07,
    glow: 0.1,
    bevel: 0,
    depth: 0,
    dispersion: 0,
    grain: false,
  );

  EvGlassStyle copyWith({
    double? blur,
    double? saturation,
    double? brightness,
    EvGlassTint? tint,
    double? tintAlpha,
    double? rimKey,
    double? rimAmbient,
    double? rimBack,
    double? sheen,
    double? glow,
    double? bevel,
    double? depth,
    double? dispersion,
    bool? grain,
  }) => EvGlassStyle(
    blur: blur ?? this.blur,
    saturation: saturation ?? this.saturation,
    brightness: brightness ?? this.brightness,
    tint: tint ?? this.tint,
    tintAlpha: tintAlpha ?? this.tintAlpha,
    rimKey: rimKey ?? this.rimKey,
    rimAmbient: rimAmbient ?? this.rimAmbient,
    rimBack: rimBack ?? this.rimBack,
    sheen: sheen ?? this.sheen,
    glow: glow ?? this.glow,
    bevel: bevel ?? this.bevel,
    depth: depth ?? this.depth,
    dispersion: dispersion ?? this.dispersion,
    grain: grain ?? this.grain,
  );

  /// Цвет заливки по палитре облика.
  Color fill(EvColors colors) => tint.of(colors).withValues(alpha: tintAlpha);

  @override
  bool operator ==(Object other) =>
      other is EvGlassStyle &&
      other.blur == blur &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.tint == tint &&
      other.tintAlpha == tintAlpha &&
      other.rimKey == rimKey &&
      other.rimAmbient == rimAmbient &&
      other.rimBack == rimBack &&
      other.sheen == sheen &&
      other.glow == glow &&
      other.bevel == bevel &&
      other.depth == depth &&
      other.dispersion == dispersion &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(
    blur,
    saturation,
    brightness,
    tint,
    tintAlpha,
    rimKey,
    rimAmbient,
    rimBack,
    sheen,
    glow,
    bevel,
    depth,
    dispersion,
    grain,
  );
}
