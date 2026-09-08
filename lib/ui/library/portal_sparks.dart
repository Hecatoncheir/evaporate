import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Голова, идущая по кругу вокруг обложки.
///
/// Их немного, и живут они долго: это они и создают вращение. Всё остальное
/// — след, который они за собой роняют.
class PortalHead {
  PortalHead({required this.at, required this.angular, required this.radius});

  /// Доля пути вдоль кромки, 0..1.
  double at;

  /// Оборотов вокруг обложки в секунду.
  final double angular;

  /// На сколько точек идёт снаружи кромки.
  final double radius;
}

/// Искра, сброшенная головой и оставшаяся позади.
///
/// Живёт доли секунды и уходит недалеко: к тому времени, как она разлетелась
/// и погасла, голова уже далеко впереди. Из этого и складывается шлейф —
/// он не рисуется отрезком, а состоит из настоящих частиц.
class PortalSpark {
  PortalSpark({
    required this.at,
    required this.along,
    required this.radius,
    required this.radial,
    required this.life,
    required this.maxLife,
  });

  /// Доля пути вдоль кромки — там, где её обронили.
  double at;

  /// Остаток движения головы: искра ещё немного идёт следом, потом встаёт.
  double along;

  /// На сколько отошла наружу от кромки, в точках.
  double radius;

  /// Скорость ухода в сторону — маленькая: разлетаться далеко ей незачем.
  double radial;

  double life;
  final double maxLife;
}

/// Точка кромки: где она и куда от неё наружу.
typedef PortalEdge = ({Offset point, Offset outward, Offset along});

/// Искры вокруг обложки выбранной игры.
///
/// Кромка повторяет контур обложки, а не окружность: обложка вытянута два к
/// трём, и вписанный в неё круг оставил бы половину плитки пустой.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed) {
    for (var i = 0; i < headCount; i++) {
      heads.add(
        PortalHead(
          // Разводим по кругу, чтобы вращение читалось сразу, а не через
          // пол-оборота.
          at: i / headCount,
          angular: _rand(0.32, 0.46),
          radius: _rand(0, 5),
        ),
      );
    }
  }

  /// Сколько голов идёт по кругу. Немного: каждая должна читаться отдельно,
  /// иначе вместо вращения выходит сплошное кольцо.
  static const headCount = 22;

  /// Предел на случай просадки кадров: след держится сменой, а не числом.
  static const maxCount = 1400;

  /// Сколько искр роняется в секунду — всеми головами вместе.
  static const rate = 4200.0;

  /// Насколько поле шире обложки. В этой полосе искры и живут: дальше они
  /// налезали бы на соседние обложки в сетке.
  static const halo = 34.0;

  /// Сопротивление: доля скорости, теряемая за секунду. Оно и держит след
  /// коротким — искра почти сразу встаёт там, где её обронили.
  static const drag = 5.5;

  final math.Random _random;
  final List<PortalHead> heads = [];
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

  /// Двигает головы и их след на [dt] секунд.
  ///
  /// Шаг ограничен сверху: после свёрнутого окна или просадки приходит
  /// секунда разом, и без предела головы проскочили бы пол-оборота.
  void advance(double dt) {
    if (size.isEmpty) return;
    final step = dt.clamp(0.0, 1 / 30);
    time += step;

    for (final head in heads) {
      head.at += head.angular * step;
    }

    final slow = math.max(0.0, 1 - drag * step);
    for (final spark in sparks) {
      spark.at += spark.along * step;
      spark.radius += spark.radial * step;
      spark.along *= slow;
      spark.radial *= slow;
      spark.life -= step;
    }
    sparks.removeWhere((spark) => spark.life <= 0);

    _budget += rate * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      final head = heads[_random.nextInt(heads.length)];
      final life = _rand(0.22, 0.62);
      sparks.add(
        PortalSpark(
          // Рождается там, где сейчас голова, — оттого след и тянется за
          // ней, а не появляется по всему кругу разом.
          at: head.at,
          // Немного её движения искра уносит с собой и тут же теряет.
          along: head.angular * _rand(0.1, 0.5),
          radius: head.radius,
          // В сторону — чуть-чуть: далеко разлетаться ей незачем.
          radial: _rand(-18, 62),
          life: life,
          maxLife: life,
        ),
      );
    }
    if (_budget > rate) _budget = rate;
  }

  /// Где искра находится сейчас.
  Offset positionOf(PortalSpark spark) => at(spark.at, spark.radius);

  /// Где голова находится сейчас.
  Offset positionOfHead(PortalHead head) => at(head.at, head.radius);

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
      ..style = PaintingStyle.fill
      // Складываем свет, а не закрашиваем: сгущение искр должно
      // разгораться, а не перекрывать само себя.
      ..blendMode = BlendMode.plus;

    // Сначала след — головы поверх него, иначе они тонули бы в собственных
    // искрах.
    for (final spark in field.sparks) {
      final fade = (spark.life / spark.maxLife).clamp(0.0, 1.0);
      paint
        ..color = Color.lerp(
          AppColors.portalRim,
          AppColors.portalSpark,
          fade,
        )!.withValues(alpha: fade * fade * (dark ? 0.95 : 0.8))
        // Искра — точка, а не штрих: шлейф складывается из них самих, и
        // рисовать каждую чёрточкой значило бы рисовать шлейф дважды.
        ..strokeWidth = 0;
      canvas.drawCircle(field.positionOf(spark), 0.8 + 2.0 * fade, paint);
    }

    for (final head in field.heads) {
      final at = field.positionOfHead(head);
      canvas
        ..drawCircle(
          at,
          5,
          Paint()
            ..color = AppColors.portalSpark.withValues(alpha: 0.35)
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawCircle(
          at,
          1.9,
          Paint()
            ..color = AppColors.portalSpark
            ..blendMode = BlendMode.plus,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
