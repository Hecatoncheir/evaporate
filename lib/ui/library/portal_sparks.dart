import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Искра покидает контур по касательной и дальше летит свободно.
/// Привязка живой частицы к периметру заставляла её огибать углы карточки
/// по рельсам и растягивала след в длинные прямоугольные полосы.
class PortalSpark {
  PortalSpark({
    required this.position,
    required this.velocity,
    required this.twinkle,
    required this.life,
    required this.maxLife,
    required this.trail,
  });

  Offset position;
  Offset velocity;
  final double twinkle;
  double life;
  final double maxLife;
  final double trail;
}

typedef PortalEdge = ({Offset point, Offset outward, Offset along});

/// Золотой вихрь по форме обложки: горячие участки кромки, короткие
/// светящиеся следы и редкие угольки, вылетающие наружу.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed);

  static const maxCount = 3600;
  static const rate = 4400.0;
  static const halo = 48.0;
  static const corner = 8.0;
  static const drag = 1.4;

  final math.Random _random;
  final List<PortalSpark> sparks = [];
  Size size = Size.zero;
  double time = 0;
  double lastFrame = 0;
  double _budget = 0;

  double _rand(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  void resize(Size value) {
    if (!value.isFinite || value.isEmpty || value == size) return;
    size = value;
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
    for (final spark in sparks) {
      _move(spark, step);
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
      final double at;
      if (_random.nextDouble() < 0.65) {
        // Несколько движущихся очагов дают вспышки и разрывы, как у портала.
        at = _random.nextInt(5) / 5 + time * 0.13 + _rand(-0.035, 0.035);
      } else {
        at = _random.nextDouble();
      }
      final edge = edgeAt(at);
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
    _budget = math.min(_budget, 1);
  }

  void _move(PortalSpark spark, double dt) {
    spark.position += spark.velocity * dt;
    spark.velocity = spark.velocity * math.exp(-drag * dt) + Offset(0, 20 * dt);
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

  /// Точка кромки по доле пути [at] вдоль периметра.
  ///
  /// Кромка — прямоугольник обложки со скруглёнными углами, и скругление
  /// тут не украшение: у острого угла наружу некуда лететь по диагонали —
  /// нормаль скачком переходит с одной стороны на другую, и угол выглядит
  /// срезанным. На дуге она поворачивается плавно, и сноп огибает угол.
  PortalEdge edgeAt(double at) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) {
      return (
        point: Offset.zero,
        outward: const Offset(0, -1),
        along: const Offset(1, 0),
      );
    }

    final r = math.min(corner, math.min(w, h) / 2);
    final flatX = w - r * 2;
    final flatY = h - r * 2;
    final quarter = math.pi / 2 * r;
    final perimeter = (flatX + flatY) * 2 + quarter * 4;

    final t = at % 1.0;
    var s = (t < 0 ? t + 1 : t) * perimeter;

    // Верх, правый верхний угол, право, правый нижний, низ, левый нижний,
    // лево, левый верхний — в порядке обхода по часовой стрелке.
    if (s < flatX) {
      return (
        point: Offset(r + s, 0),
        outward: const Offset(0, -1),
        along: const Offset(1, 0),
      );
    }
    s -= flatX;
    if (s < quarter) {
      return _arc(Offset(w - r, r), r, -math.pi / 2 + s / r);
    }
    s -= quarter;
    if (s < flatY) {
      return (
        point: Offset(w, r + s),
        outward: const Offset(1, 0),
        along: const Offset(0, 1),
      );
    }
    s -= flatY;
    if (s < quarter) {
      return _arc(Offset(w - r, h - r), r, s / r);
    }
    s -= quarter;
    if (s < flatX) {
      return (
        point: Offset(w - r - s, h),
        outward: const Offset(0, 1),
        along: const Offset(-1, 0),
      );
    }
    s -= flatX;
    if (s < quarter) {
      return _arc(Offset(r, h - r), r, math.pi / 2 + s / r);
    }
    s -= quarter;
    if (s < flatY) {
      return (
        point: Offset(0, h - r - s),
        outward: const Offset(-1, 0),
        along: const Offset(0, -1),
      );
    }
    s -= flatY;
    return _arc(Offset(r, r), r, math.pi + s / r);
  }

  /// Точка на дуге угла: наружу — от центра дуги, вдоль — по касательной.
  static PortalEdge _arc(Offset center, double radius, double angle) {
    final outward = Offset(math.cos(angle), math.sin(angle));
    return (
      point: center + outward * radius,
      outward: outward,
      along: Offset(-outward.dy, outward.dx),
    );
  }
}

/// Обёртка, рисующая разлёт искр вокруг плитки.
class PortalSparks extends StatefulWidget {
  const PortalSparks({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<PortalSparks> createState() => PortalSparksState();
}

class PortalSparksState extends State<PortalSparks> {
  /// Разлёт живёт в состоянии, а не в рисовальщике: тот создаётся заново при
  /// каждой пересборке плитки — а плитка пересобирается на каждом переводе
  /// выделения. Искры начинали бы с чистого места и вспыхивали разом.
  @visibleForTesting
  final PortalSparkField field = PortalSparkField();

  @override
  void didUpdateWidget(PortalSparks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      // DecorativeMotion создаёт новые часы при возвращении выделения.
      // Старое показание иначе замораживает первый кадр прежнего потока.
      field.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      field.reset();
      return widget.child;
    }

    const halo = PortalSparkField.halo;
    return DecorativeMotion(
      enabled: true,
      child: widget.child,
      // Кайма выходит за плитку, поэтому обрезать нельзя: в ней-то искры и
      // видны. Промежутка между обложками в сетке на неё хватает.
      builder: (context, clock, child) => Stack(
        // Растягиваем: у свободных ограничений обложка без собственного
        // размера схлопнулась бы в точку, и от плитки осталась бы кайма.
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Под обложкой: то, что залетело на неё, скрыто, и остаётся ровно
          // разлёт вокруг — а не рябь поверх картинки.
          Positioned(
            left: -halo,
            top: -halo,
            right: -halo,
            bottom: -halo,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('portal-sparks'),
                  painter: _PortalPainter(
                    clock: clock,
                    field: field,
                    dark: context.colors.isDark,
                  ),
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
    );
  }
}

class _PortalPainter extends CustomPainter {
  _PortalPainter({required this.clock, required this.field, required this.dark})
    : super(repaint: clock);

  final ValueListenable<double> clock;
  final PortalSparkField field;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const halo = PortalSparkField.halo;
    final inner = Size(size.width - halo * 2, size.height - halo * 2);
    if (inner.isEmpty) return;

    field.resize(inner);
    field.advance(clock.value - field.lastFrame);
    field.lastFrame = clock.value;

    canvas.save();
    // Кромка считается по обложке, а слой шире её на кайму: разлёт уносит
    // искры именно туда, где им и место — вокруг, а не поверх.
    canvas.translate(halo, halo);

    // Кромка состоит из отдельных раскалённых штрихов. Сплошная
    // размытая рамка давала ровный неоновый прямоугольник вместо искр.
    const buckets = 6;
    final lines = List.generate(buckets, (_) => <double>[]);
    final perimeter = (inner.width + inner.height) * 2;
    final segments = (perimeter / 1.4).ceil();
    for (var i = 0; i < segments; i++) {
      final at = i / segments;
      final wave = math.sin(at * math.pi * 10 - field.time * 4.1);
      final grain = math.sin(i * 2.399 + field.time * 19);
      final intensity = (0.35 + wave * 0.35 + grain * 0.3).clamp(0.0, 1.0);
      if (intensity < 0.22) continue;
      final edge = field.edgeAt(at);
      final head = edge.point + edge.outward * (1.4 + grain * 0.8);
      final tail = head - edge.along * (0.6 + intensity * 2.4);
      final bucket = (intensity * (buckets - 1)).round();
      lines[bucket].addAll([tail.dx, tail.dy, head.dx, head.dy]);
    }
    for (final spark in field.sparks) {
      final brightness = field.brightnessOf(spark);
      if (brightness < 0.035) continue;
      final bucket = math.min(buckets - 1, (brightness * buckets).floor());
      final head = field.positionOf(spark);
      final tail = field.tailOf(spark);
      lines[bucket].addAll([tail.dx, tail.dy, head.dx, head.dy]);
    }

    for (var i = 0; i < buckets; i++) {
      if (lines[i].isEmpty) continue;
      final points = Float32List.fromList(lines[i]);
      final heat = (i + 1) / buckets;
      final blend = dark ? BlendMode.plus : BlendMode.srcOver;
      // Слабый оранжевый ореол вокруг отдельных искр, затем резкая
      // золотая сердцевина. Без общего размытия сохраняются тёмные просветы.
      canvas.drawRawPoints(
        PointMode.lines,
        points,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4 + heat
          ..blendMode = blend
          ..color = AppColors.portalRim.withValues(alpha: heat * 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawRawPoints(
        PointMode.lines,
        points,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.45 + heat * 0.75
          ..blendMode = blend
          ..color = Color.lerp(
            AppColors.portalRim,
            AppColors.portalSpark,
            heat * heat,
          )!.withValues(alpha: 0.15 + heat * 0.85),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
