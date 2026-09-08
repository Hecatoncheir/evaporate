import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Искра, кружащая вокруг обложки.
///
/// Движение разложено на два: угловое — вдоль кромки, и наружное — прочь от
/// неё. Свободный полёт по прямой давал брызги, но не вихрь; движение по
/// одной лишь кромке — дрожащую обводку. Вихрь получается, когда есть оба
/// сразу, и хвост считается в тех же координатах, поэтому он изгибается по
/// дуге, а не тянется чертой.
class PortalSpark {
  PortalSpark({
    required this.at,
    required this.angular,
    required this.radius,
    required this.radial,
    required this.life,
    required this.maxLife,
  });

  /// Доля пути вдоль кромки, 0..1.
  double at;

  /// Оборотов вокруг обложки в секунду, со знаком.
  final double angular;

  /// Насколько отошла наружу от кромки, в точках.
  double radius;

  /// Скорость ухода наружу, в точках в секунду. Гасится сопротивлением.
  double radial;

  /// Сколько осталось, в секундах.
  double life;

  /// Сколько было отпущено — по остатку от неё искра и гаснет.
  final double maxLife;
}

/// Точка кромки: где она и куда от неё наружу.
typedef PortalEdge = ({Offset point, Offset outward, Offset along});

/// Вихрь искр вокруг обложки выбранной игры.
///
/// Кромка повторяет контур обложки, а не окружность: обложка вытянута два к
/// трём, и вписанный в неё круг оставил бы половину плитки пустой. Искры
/// кружат вдоль кромки и одновременно уходят наружу, выдыхаясь в кайме.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed);

  /// Предел на случай просадки кадров: поток держится сменой, а не числом.
  static const maxCount = 900;

  /// Сколько срывается в секунду.
  static const rate = 1300.0;

  /// Насколько поле шире обложки. В этой полосе искры и живут: дальше они
  /// налезали бы на соседние обложки в сетке.
  static const halo = 34.0;

  /// Сопротивление уходу наружу: доля скорости, теряемая за секунду. Без
  /// него искры улетали бы за экран, с ним — выдыхаются в кайме.
  static const drag = 2.6;

  final math.Random _random;
  final List<PortalSpark> sparks = [];
  Size size = Size.zero;
  double time = 0;

  /// Показание часов на прошлом кадре: шаг считается по разнице, а сами
  /// часы общие и идут независимо от того, кто на них смотрит.
  double lastFrame = 0;
  double _budget = 0;

  double _rand(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  void resize(Size value) {
    if (!value.isFinite || value.isEmpty) return;
    size = value;
  }

  /// Двигает вихрь на [dt] секунд.
  ///
  /// Шаг ограничен сверху: после свёрнутого окна или просадки приходит
  /// секунда разом, и без предела искры проскочили бы пол-оборота.
  void advance(double dt) {
    if (size.isEmpty) return;
    final step = dt.clamp(0.0, 1 / 30);
    time += step;

    final slow = math.max(0.0, 1 - drag * step);
    for (final spark in sparks) {
      spark.at += spark.angular * step;
      spark.radius += spark.radial * step;
      spark.radial *= slow;
      spark.life -= step;
    }
    sparks.removeWhere((spark) => spark.life <= 0);

    _budget += rate * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      final life = _rand(0.5, 1.2);
      sparks.add(
        PortalSpark(
          at: _random.nextDouble(),
          // Почти все в одну сторону: встречные нужны для живости, но если
          // их поровну, вращения не видно вовсе.
          angular: _rand(0.45, 1.1) * (_random.nextDouble() < 0.15 ? -1 : 1),
          radius: _rand(0, 3),
          // Дальше кромки ровно на кайму и ни точкой больше: предел —
          // это скорость, делённая на сопротивление, плюс начальный отход.
          radial: _rand(15, 76),
          life: life,
          maxLife: life,
        ),
      );
    }
    if (_budget > rate) _budget = rate;
  }

  /// Где искра находится сейчас.
  Offset positionOf(PortalSpark spark) => at(spark.at, spark.radius);

  /// Точка в стольких долях пути вдоль кромки и стольких точках наружу.
  Offset at(double along, double radius) {
    final edge = edgeAt(along);
    return edge.point + edge.outward * math.max(0, radius);
  }

  /// Точка кромки по доле пути [at] вдоль периметра.
  ///
  /// Кромка — прямоугольник обложки, поэтому идём по сторонам: доля пути
  /// раскладывается на сторону и место на ней.
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

    final t = at % 1.0;
    final along = (t < 0 ? t + 1 : t) * (w + h) * 2;

    if (along < w) {
      return (
        point: Offset(along, 0),
        outward: const Offset(0, -1),
        along: const Offset(1, 0),
      );
    }
    if (along < w + h) {
      return (
        point: Offset(w, along - w),
        outward: const Offset(1, 0),
        along: const Offset(0, 1),
      );
    }
    if (along < w * 2 + h) {
      return (
        point: Offset(w - (along - w - h), h),
        outward: const Offset(0, 1),
        along: const Offset(-1, 0),
      );
    }
    return (
      point: Offset(0, h - (along - w * 2 - h)),
      outward: const Offset(-1, 0),
      along: const Offset(0, -1),
    );
  }

  /// След искры: где она была на протяжении [seconds] до этого кадра.
  ///
  /// Считается обратным ходом в тех же координатах — вдоль кромки и наружу,
  /// — поэтому хвост изгибается по дуге вокруг обложки. Посчитай его по
  /// прямой, и вихрь снова выглядел бы разлётом.
  List<Offset> trail(
    PortalSpark spark, {
    double seconds = 0.08,
    int steps = 6,
  }) {
    final points = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final back = seconds * i / steps;
      points.add(
        at(spark.at - spark.angular * back, spark.radius - spark.radial * back),
      );
    }
    return points;
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
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

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

    // Мягкое свечение по кромке, а не обводка: широкое размытие и малая
    // плотность, иначе читается нарисованной рамкой.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & inner, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.portalRim.withValues(alpha: dark ? 0.35 : 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      // Складываем свет, а не закрашиваем: пересекающиеся искры должны
      // разгораться, как искры, а не гасить друг друга.
      ..blendMode = BlendMode.plus;

    for (final spark in field.sparks) {
      final fade = (spark.life / spark.maxLife).clamp(0.0, 1.0);
      final points = field.trail(spark);
      final hot = Color.lerp(AppColors.portalRim, AppColors.portalSpark, fade)!;

      // Хвост гаснет к концу: голова яркая и толстая, дальше сходит на нет.
      for (var i = 0; i < points.length - 1; i++) {
        final along = 1 - i / (points.length - 1);
        paint
          ..color = hot.withValues(
            alpha: fade * along * along * (dark ? 0.95 : 0.8),
          )
          ..strokeWidth = 0.5 + 2.4 * along * fade;
        canvas.drawLine(points[i + 1], points[i], paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
