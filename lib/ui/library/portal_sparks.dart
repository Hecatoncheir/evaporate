import 'dart:math' as math;
import 'dart:ui' as ui;

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
  late final _renderer = _PortalRenderer();

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
                    renderer: _renderer,
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
  _PortalPainter({
    required this.clock,
    required this.field,
    required this.renderer,
    required this.dark,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final PortalSparkField field;
  final _PortalRenderer renderer;
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

    renderer.paint(canvas, field, dark: dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock ||
      old.dark != dark ||
      old.field != field ||
      old.renderer != renderer;
}

/// Атлас один на приложение: неизменные штрихи и их ореолы растрируются
/// один раз, а не размываются тысячами заново каждый кадр. Плотность,
/// траектории и яркости симуляции при этом остаются прежними.
class _PortalAtlas {
  static const buckets = 6;
  static const resolution = 3.0;
  static const lengthStep = 0.25;
  static const variants = 25;
  static const padding = 7.0;
  static const cellWidth = 20.0;
  static const cellHeight = 14.0;
  static const pixelWidth = cellWidth * resolution;
  static const pixelHeight = cellHeight * resolution;
  static final ui.Image image = _create();

  static ui.Image _create() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(resolution);
    for (var bucket = 0; bucket < buckets; bucket++) {
      final heat = (bucket + 1) / buckets;
      final glow = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4 + heat
        ..color = AppColors.portalRim.withValues(alpha: heat * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      final core = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.45 + heat * 0.75
        ..color = Color.lerp(
          AppColors.portalRim,
          AppColors.portalSpark,
          heat * heat,
        )!.withValues(alpha: 0.15 + heat * 0.85);
      for (var variant = 0; variant < variants; variant++) {
        final x = variant * cellWidth + padding;
        final y = bucket * cellHeight + padding;
        final length = variant * lengthStep;
        canvas.drawLine(Offset(x, y), Offset(x + length, y), glow);
        canvas.drawLine(
          Offset(x, y + buckets * cellHeight),
          Offset(x + length, y + buckets * cellHeight),
          core,
        );
      }
    }
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        (variants * pixelWidth).round(),
        (buckets * 2 * pixelHeight).round(),
      );
    } finally {
      picture.dispose();
    }
  }
}

/// Буферы живут вместе с карточкой и переиспользуются на каждом кадре.
/// Вместо списков double и их копирования остаются только короткие views.
class _SparkBatch {
  Float32List _transforms = Float32List(256 * 4);
  Float32List _glowRects = Float32List(256 * 4);
  Float32List _coreRects = Float32List(256 * 4);
  int length = 0;

  void add(int bucket, double x0, double y0, double x1, double y1) {
    if (length + 4 > _transforms.length) {
      final capacity = _transforms.length * 2;
      _transforms = Float32List(capacity)..setAll(0, _transforms);
      _glowRects = Float32List(capacity)..setAll(0, _glowRects);
      _coreRects = Float32List(capacity)..setAll(0, _coreRects);
    }
    final dx = x1 - x0;
    final dy = y1 - y0;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 0.0001) return;
    final cosine = dx / distance / _PortalAtlas.resolution;
    final sine = dy / distance / _PortalAtlas.resolution;
    const inset = _PortalAtlas.padding * _PortalAtlas.resolution;
    final variant = (distance / _PortalAtlas.lengthStep).round().clamp(
      0,
      _PortalAtlas.variants - 1,
    );
    final left = variant * _PortalAtlas.pixelWidth;
    final top = bucket * _PortalAtlas.pixelHeight;
    const coreOffset = _PortalAtlas.buckets * _PortalAtlas.pixelHeight;
    final i = length;
    _transforms[i] = cosine;
    _transforms[i + 1] = sine;
    _transforms[i + 2] = x0 - cosine * inset + sine * inset;
    _transforms[i + 3] = y0 - sine * inset - cosine * inset;
    _glowRects[i] = _coreRects[i] = left;
    _glowRects[i + 1] = top;
    _coreRects[i + 1] = top + coreOffset;
    _glowRects[i + 2] = _coreRects[i + 2] = left + _PortalAtlas.pixelWidth;
    _glowRects[i + 3] = top + _PortalAtlas.pixelHeight;
    _coreRects[i + 3] = top + coreOffset + _PortalAtlas.pixelHeight;
    length += 4;
  }

  void paint(Canvas canvas, Paint paint) {
    if (length == 0) return;
    final transforms = Float32List.sublistView(_transforms, 0, length);
    // Порядок проходов такой же, как у исходного эффекта: ореолы корзины,
    // затем её сердцевины. Это сохраняет смешение пересекающихся искр.
    canvas.drawRawAtlas(
      _PortalAtlas.image,
      transforms,
      Float32List.sublistView(_glowRects, 0, length),
      null,
      null,
      null,
      paint,
    );
    canvas.drawRawAtlas(
      _PortalAtlas.image,
      transforms,
      Float32List.sublistView(_coreRects, 0, length),
      null,
      null,
      null,
      paint,
    );
  }
}

class _PortalRenderer {
  final _batches = List.generate(_PortalAtlas.buckets, (_) => _SparkBatch());
  final _paint = Paint()..filterQuality = FilterQuality.low;
  Size _size = Size.zero;
  Float64List _rim = Float64List(0);

  void _resize(PortalSparkField field) {
    if (_size == field.size) return;
    _size = field.size;
    final segments = ((_size.width + _size.height) * 2 / 1.4).ceil();
    _rim = Float64List(segments * 10);
    for (var i = 0; i < segments; i++) {
      final at = i / segments;
      final edge = field.edgeAt(at);
      final j = i * 10;
      _rim[j] = edge.point.dx;
      _rim[j + 1] = edge.point.dy;
      _rim[j + 2] = edge.outward.dx;
      _rim[j + 3] = edge.outward.dy;
      _rim[j + 4] = edge.along.dx;
      _rim[j + 5] = edge.along.dy;
      _rim[j + 6] = math.sin(at * math.pi * 10);
      _rim[j + 7] = math.cos(at * math.pi * 10);
      _rim[j + 8] = math.sin(i * 2.399);
      _rim[j + 9] = math.cos(i * 2.399);
    }
  }

  void paint(Canvas canvas, PortalSparkField field, {required bool dark}) {
    _resize(field);
    for (final batch in _batches) {
      batch.length = 0;
    }
    // Геометрия контура постоянна. Формулы сложения синусов оставляют
    // четыре тригонометрических вызова на кадр вместо двух на каждый штрих.
    final waveSin = math.sin(field.time * 4.1);
    final waveCos = math.cos(field.time * 4.1);
    final grainSin = math.sin(field.time * 19);
    final grainCos = math.cos(field.time * 19);
    for (var i = 0; i < _rim.length; i += 10) {
      final wave = _rim[i + 6] * waveCos - _rim[i + 7] * waveSin;
      final grain = _rim[i + 8] * grainCos + _rim[i + 9] * grainSin;
      final intensity = (0.35 + wave * 0.35 + grain * 0.3).clamp(0.0, 1.0);
      if (intensity < 0.22) continue;
      final x = _rim[i] + _rim[i + 2] * (1.4 + grain * 0.8);
      final y = _rim[i + 1] + _rim[i + 3] * (1.4 + grain * 0.8);
      final trail = 0.6 + intensity * 2.4;
      final bucket = (intensity * (_PortalAtlas.buckets - 1)).round();
      _batches[bucket].add(
        bucket,
        x - _rim[i + 4] * trail,
        y - _rim[i + 5] * trail,
        x,
        y,
      );
    }
    for (final spark in field.sparks) {
      final brightness = field.brightnessOf(spark);
      if (brightness < 0.035) continue;
      final bucket = math.min(
        _PortalAtlas.buckets - 1,
        (brightness * _PortalAtlas.buckets).floor(),
      );
      final x = spark.position.dx;
      final y = spark.position.dy;
      _batches[bucket].add(
        bucket,
        x - spark.velocity.dx * spark.trail,
        y - spark.velocity.dy * spark.trail,
        x,
        y,
      );
    }
    _paint.blendMode = dark ? BlendMode.plus : BlendMode.srcOver;
    for (final batch in _batches) {
      batch.paint(canvas, _paint);
    }
  }
}
