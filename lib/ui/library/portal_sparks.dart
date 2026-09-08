import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Искра сварки: летит от кромки наружу, снесённая вращением вбок, и
/// мерцает, пока не погаснет.
class PortalSpark {
  PortalSpark({
    required this.at,
    required this.angular,
    required this.radius,
    required this.radial,
    required this.twinkle,
    required this.life,
    required this.maxLife,
  });

  /// Доля пути вдоль кромки, 0..1.
  double at;

  /// Оборотов вокруг обложки в секунду: это вращение и сносит искру вбок,
  /// отчего веер закручивается, а не расходится по радиусам.
  double angular;

  /// На сколько отошла наружу от кромки, в точках.
  double radius;

  /// Скорость ухода наружу. Разброс её и делает веер широким: часть искр
  /// гаснет у самой кромки, часть долетает до края каймы.
  double radial;

  /// Сдвиг мерцания. Без него все искры вспыхивали бы разом и поле дышало
  /// бы целиком, вместо того чтобы искрить.
  final double twinkle;

  double life;
  final double maxLife;
}

/// Точка кромки: где она и куда от неё наружу.
typedef PortalEdge = ({Offset point, Offset outward, Offset along});

/// Сноп искр вокруг обложки выбранной игры.
///
/// Кромка повторяет контур обложки, а не окружность: обложка вытянута два к
/// трём, и вписанный в неё круг оставил бы половину плитки пустой.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed);

  /// Предел на случай просадки кадров: сноп держится сменой, а не числом.
  static const maxCount = 9000;

  /// Сколько искр срывается в секунду. Сварка — это густо: редкий сноп
  /// читается не искрами, а сором вокруг обложки.
  static const rate = 12000.0;

  /// Насколько поле шире обложки. Дальше искры залетают на соседние
  /// обложки — там они не мешают, но и держать их там незачем.
  static const halo = 56.0;

  /// Сопротивление: доля скорости, теряемая за секунду. Небольшое —
  /// искра должна успеть пересечь кайму, пока горит, а не встать у шва.
  static const drag = 0.6;

  /// Частота мерцания, оборотов в секунду.
  static const flicker = 9.0;

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

  /// Двигает сноп на [dt] секунд.
  ///
  /// Шаг ограничен сверху: после свёрнутого окна или просадки приходит
  /// секунда разом, и без предела искры улетели бы неведомо куда.
  void advance(double dt) {
    if (size.isEmpty) return;
    final step = dt.clamp(0.0, 1 / 30);
    time += step;

    final slow = math.max(0.0, 1 - drag * step);
    for (final spark in sparks) {
      spark.at += spark.angular * step;
      spark.radius += spark.radial * step;
      spark.radial *= slow;
      // Вбок искру сносит слабее по мере удаления: у кромки вращение
      // тащит её заметно, дальше она летит почти по прямой.
      spark.angular *= slow;
      spark.life -= step;
    }
    // Долетевшую до края каймы гасим: держать её дальше значит светить по
    // соседним обложкам, а обрывать на месте — упереть сноп в стенку.
    sparks.removeWhere((spark) => spark.life <= 0 || spark.radius > halo);

    _budget += rate * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      final life = _rand(0.35, 1.25);
      sparks.add(
        PortalSpark(
          // Срываются по всей кромке разом: у сварки нет одной точки, из
          // которой всё летит.
          at: _random.nextDouble(),
          angular: _rand(0.3, 0.9) * (_random.nextDouble() < 0.12 ? -1 : 1),
          radius: _rand(0, 2),
          // Разброс смещён к малым скоростям: у сварки густо у шва и
          // редко по краям, а ровный разброс дал бы одинаковую пелену.
          radial: 18 + 140 * math.pow(_random.nextDouble(), 1.05).toDouble(),
          twinkle: _random.nextDouble() * math.pi * 2,
          life: life,
          maxLife: life,
        ),
      );
    }
    if (_budget > rate) _budget = rate;
  }

  /// Яркость искры сейчас: гаснет к концу жизни и мерцает.
  double brightnessOf(PortalSpark spark) {
    final fade = (spark.life / spark.maxLife).clamp(0.0, 1.0);
    final blink = 0.55 + 0.45 * math.sin(time * flicker + spark.twinkle);
    return math.pow(fade, 1.3) * blink;
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
    // Кольцо горит само: у сварки светится шов, а не только искры от него.
    // Два прохода — широкое зарево и узкий раскалённый край.
    final ring = RRect.fromRectAndRadius(
      Offset.zero & inner,
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..blendMode = BlendMode.plus
          ..color = AppColors.portalRim.withValues(alpha: dark ? 0.4 : 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      )
      ..drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..blendMode = BlendMode.plus
          ..color = AppColors.portalSpark.withValues(alpha: dark ? 0.7 : 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

    // Тысячи искр — тысячи вызовов рисования, если делать их по одной.
    // `drawRawPoints` кладёт целую пачку за раз, поэтому искры разложены по
    // корзинам яркости: внутри корзины цвет и размер общие.
    //
    // Считаем в два прохода, чтобы не растить списки: сперва сколько куда
    // попадёт, потом заполняем массивы точной длины. При девяти тысячах
    // искр в кадре растущий список стоил бы дороже самой отрисовки.
    const buckets = 4;
    final counts = List.filled(buckets, 0);
    final bucketOf = <PortalSpark, int>{};
    for (final spark in field.sparks) {
      final brightness = field.brightnessOf(spark);
      if (brightness <= 0.02) continue;
      final bucket = math.min(buckets - 1, (brightness * buckets).floor());
      bucketOf[spark] = bucket;
      counts[bucket]++;
    }

    final points = [for (final count in counts) Float32List(count * 2)];
    final filled = List.filled(buckets, 0);
    for (final entry in bucketOf.entries) {
      final bucket = entry.value;
      final at = field.positionOf(entry.key);
      final i = filled[bucket]++;
      points[bucket][i * 2] = at.dx;
      points[bucket][i * 2 + 1] = at.dy;
    }

    for (var i = 0; i < buckets; i++) {
      if (counts[i] == 0) continue;
      final brightness = (i + 0.5) / buckets;
      canvas.drawRawPoints(
        PointMode.points,
        points[i],
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.1 + 2.2 * brightness
          // Складываем свет, а не закрашиваем: сгущение искр должно
          // разгораться, а не перекрывать само себя.
          ..blendMode = BlendMode.plus
          ..color = Color.lerp(
            AppColors.portalRim,
            AppColors.portalSpark,
            brightness,
          )!.withValues(alpha: brightness * (dark ? 1 : 0.85)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
