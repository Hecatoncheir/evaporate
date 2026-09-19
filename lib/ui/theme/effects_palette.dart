import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'decor_colors.dart';

/// Облик украшений библиотеки в каждой схеме.
///
/// Прежде схему выбирал вызывающий: `waveColors(dark: …)`,
/// `particleColor(isDark: …)`, флаг `dark` в художниках волны и искр. Теперь
/// выбор делает тема, а украшение берёт свои значения, не спрашивая, какая
/// схема сейчас, — и третьей схеме хватит третьего экземпляра.
@immutable
class EffectsPalette extends ThemeExtension<EffectsPalette> {
  const EffectsPalette({
    required this.waveColors,
    required this.waveStrength,
    required this.particleBase,
    required this.sparkBlend,
    required this.ambientWash,
  });

  /// Цвета волны на странице игры.
  final List<Color> waveColors;

  /// Сила волны: на светлом корпусе полная читалась бы пятном.
  final double waveStrength;

  /// Цвет частицы без свечения; со свечением она тянется к цветам
  /// [libraryInkColors].
  final Color particleBase;

  /// Как искры ложатся на подложку. Ночью — сложением: свет на тёмном
  /// корпусе. Днём сложение выжгло бы искры в белое, и они просто рисуются.
  final BlendMode sparkBlend;

  /// Медленный перламутр под сеткой. Только днём: ночью его место занимает
  /// свет самих игр.
  final bool ambientWash;

  static const arclight = EffectsPalette(
    waveColors: [
      Color(0xFFE9C877),
      Color(0xFF49B7E0),
      Color(0xFFE0574A),
      Color(0xFFC9C2B2),
    ],
    waveStrength: 1,
    particleBase: Color(0xFFE9C877),
    sparkBlend: BlendMode.plus,
    ambientWash: false,
  );

  static const cartridge = EffectsPalette(
    waveColors: [
      Color(0xFFFF4A17),
      Color(0xFFFFC400),
      Color(0xFF0090A8),
      Color(0xFFB3261E),
    ],
    waveStrength: 0.8,
    particleBase: Color(0xFF8C3A10),
    sparkBlend: BlendMode.srcOver,
    ambientWash: true,
  );

  static EffectsPalette of(BuildContext context) =>
      Theme.of(context).extension<EffectsPalette>() ?? arclight;

  /// Цвет частицы: от базового к одному из цветов туши по мере свечения.
  Color particle({required double phase, required double glow}) => Color.lerp(
    particleBase,
    libraryInkColors[(phase * 10).floor() % 5],
    glow,
  )!;

  @override
  EffectsPalette copyWith({Color? particleBase}) => EffectsPalette(
    waveColors: waveColors,
    waveStrength: waveStrength,
    particleBase: particleBase ?? this.particleBase,
    sparkBlend: sparkBlend,
    ambientWash: ambientWash,
  );

  /// Цвета смешиваются плавно, а режим наложения и перламутр —
  /// переключаются посередине: промежуточного у них не бывает.
  @override
  EffectsPalette lerp(ThemeExtension<EffectsPalette>? other, double t) {
    if (other is! EffectsPalette) return this;
    final half = t < 0.5 ? this : other;
    return EffectsPalette(
      waveColors: [
        for (var i = 0; i < waveColors.length; i++)
          Color.lerp(waveColors[i], other.waveColors[i], t)!,
      ],
      waveStrength: lerpDouble(waveStrength, other.waveStrength, t)!,
      particleBase: Color.lerp(particleBase, other.particleBase, t)!,
      sparkBlend: half.sparkBlend,
      ambientWash: half.ambientWash,
    );
  }
}
