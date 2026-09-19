import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'portal_outline.dart';
import 'portal_spark.dart';

/// Золотой вихрь по форме обложки: горячие участки кромки, короткие
/// светящиеся следы и редкие угольки, вылетающие наружу.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed);

  static const maxCount = 3600;
  static const rate = 4400.0;
  static const halo = 48.0;
  static const drag = 1.4;

  final math.Random _random;
  final List<PortalSpark> sparks = [];

  /// Кромка, с которой они срываются. Размер у неё тот же, что у снопа.
  final outline = PortalOutline();

  double time = 0;
  double lastFrame = 0;
  double _budget = 0;

  Size get size => outline.size;

  double _rand(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  void resize(Size value) {
    if (!value.isFinite || value.isEmpty || value == size) return;
    outline.size = value;
    reset();
  }

  void reset() {
    sparks.clear();
    _budget = 0;
    lastFrame = 0;
  }

  void advance(double dt) {
    if (size.isEmpty || !dt.isFinite || dt <= 0) return;
    final step = dt.clamp(0.0, 1 / 30);
    time += step;
    final attenuation = math.exp(-drag * step);
    for (final spark in sparks) {
      _move(spark, step, attenuation);
    }
    final bounds = (Offset.zero & size).inflate(halo - 5);
    sparks.removeWhere(
      (spark) => spark.life <= 0 || !bounds.contains(spark.position),
    );

    // Плотность масштабируется с периметром: маленькая карточка не
    // превращается в сплошное белое пятно от того же числа частиц.
    _budget += rate * ((size.width + size.height) / 500).clamp(0.4, 1.8) * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      _emit(step);
    }
    _budget = math.min(_budget, 1);
  }

  /// Рождение одной искры на кромке.
  void _emit(double step) {
    final double at;
    if (_random.nextDouble() < 0.65) {
      // Несколько движущихся очагов дают вспышки и разрывы, как у портала.
      at = _random.nextInt(5) / 5 + time * 0.13 + _rand(-0.035, 0.035);
    } else {
      at = _random.nextDouble();
    }
    final edge = outline.edgeAt(at);
    final life = _rand(0.22, 0.72);
    final speed = _rand(55, 160);
    final spark = PortalSpark(
      position: edge.point + edge.outward * _rand(0.5, 4.5),
      velocity:
          edge.along * speed +
          edge.outward *
              (10 + 85 * math.pow(_random.nextDouble(), 1.9).toDouble()),
      twinkle: _rand(0, math.pi * 2),
      life: life,
      maxLife: life,
      trail: _rand(0.008, 0.028),
    );
    // Разное время рождения внутри кадра убирает одинаковые ряды искр.
    _move(spark, _rand(0, step));
    sparks.add(spark);
  }

  void _move(PortalSpark spark, double dt, [double? attenuation]) {
    spark.position += spark.velocity * dt;
    spark.velocity =
        spark.velocity * (attenuation ?? math.exp(-drag * dt)) +
        Offset(0, 20 * dt);
    spark.life -= dt;
  }

  double brightnessOf(PortalSpark spark) {
    final fade = (spark.life / spark.maxLife).clamp(0.0, 1.0);
    final blink = 0.75 + 0.25 * math.sin(time * 43 + spark.twinkle);
    return math.pow(fade, 1.35).toDouble() * blink;
  }

  Offset positionOf(PortalSpark spark) => spark.position;
  Offset tailOf(PortalSpark spark) =>
      spark.position - spark.velocity * spark.trail;
}
