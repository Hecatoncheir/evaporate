import 'package:flutter/widgets.dart';

import '../design/effects.dart';
import '../design/theme.dart';

/// Мягкий край полосы каркаса.
///
/// Под матовой полосой содержимое обрывалось бы резкой границей: тут
/// размыто, а на пиксель ниже — нет. Край продолжает размытие полосы и
/// сводит его на нет, а затемнение — одним градиентом, и переход читается
/// как глубина, а не как шов. В iOS это называется scroll edge effect.
///
/// Размытие с переменным радиусом стоило бы отдельного прохода, поэтому
/// оно ступенчатое — но ступеней восемь, первая начинается с размытия
/// самой полосы, а соседние отличаются меньше чем в полтора раза. Было три
/// ступени, начиная с трети полосы, и у каждой своя ровная заливка: на
/// стыках радиус и затемнение прыгали, и шов был виден.
class EvScrollEdge extends StatelessWidget {
  const EvScrollEdge({
    super.key,
    this.height = 32,
    this.fromTop = true,
    this.blur = 22,
  });

  /// Высота перехода.
  final double height;

  /// Полоса сверху: размытие слабеет вниз. Иначе — наоборот.
  final bool fromTop;

  /// Размытие у самой полосы — то же, что у её инея.
  final double blur;

  static const _steps = 8;

  /// Затемнение у самой полосы; к дальнему краю сходит на нет.
  static const _shade = .3;

  @override
  Widget build(BuildContext context) {
    final c = context.evc;
    final effects = EvEffectsScope.maybeOf(context);
    if (!(effects?.glass ?? true)) return SizedBox(height: height);
    final scale = (effects?.quality ?? EvEffectsQuality.full).blurScale;
    final strips = [
      for (final sigma in sigmas(blur * scale))
        _EdgeStrip(height: height / _steps, sigma: sigma),
    ];
    final ordered = fromTop ? strips : strips.reversed.toList();
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Column(children: ordered),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: fromTop
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      for (var i = 0; i <= 4; i++)
                        c.ground.withValues(alpha: _shade * _falloff(i / 4)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Размытие ступеней от полосы вглубь. Квадрат остатка: у полосы
  /// радиус почти её, дальше спадает всё мягче и у края незаметен.
  @visibleForTesting
  static List<double> sigmas(double blur) => [
    for (var i = 0; i < _steps; i++) blur * _falloff((i + .5) / _steps),
  ];

  /// От 1 у полосы к 0 у дальнего края, с плавным хвостом.
  static double _falloff(double t) => (1 - t) * (1 - t);
}

class _EdgeStrip extends StatelessWidget {
  const _EdgeStrip({required this.height, required this.sigma});

  final double height;
  final double sigma;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter.grouped(
      filterConfig: ImageFilterConfig.blur(sigmaX: sigma, sigmaY: sigma),
      child: SizedBox(height: height, width: double.infinity),
    ),
  );
}
