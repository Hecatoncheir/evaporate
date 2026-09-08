import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Искра, бегущая по контуру обложки.
///
/// Положение хранится долей пути по периметру, а не точкой: так искру можно
/// гнать с постоянной скоростью по любому контуру, не пересчитывая
/// направление на каждом углу.
class PortalSpark {
  PortalSpark({
    required this.at,
    required this.speed,
    required this.drift,
    required this.driftSpeed,
    required this.life,
    required this.maxLife,
  });

  /// Доля пути по периметру, 0..1.
  double at;

  /// Долей периметра в секунду. Разброс скоростей и делает поток потоком:
  /// с одинаковой все искры выглядели бы спицами колеса.
  final double speed;

  /// Насколько искра отошла наружу от контура, в точках.
  double drift;

  /// С какой скоростью отходит, в точках в секунду. Хранится отдельно от
  /// самого сноса затем, что шлейф строится обратным ходом: где искра была
  /// долю секунды назад, считается по её же скорости.
  double driftSpeed;

  /// Сколько ей осталось, в секундах.
  double life;

  /// Сколько было отпущено — по остатку от неё и гаснет хвост.
  final double maxLife;
}

/// Кольцо искр вокруг обложки выбранной игры.
///
/// Контур повторяет саму обложку, а не окружность: обложка вытянута два к
/// трём, и вписанный в неё круг оставил бы половину плитки пустой. Искры
/// идут по краю, снося наружу и угасая, — движение то же, что у портала.
class PortalSparkField {
  PortalSparkField({int seed = 17}) : _random = math.Random(seed);

  /// Больше не нужно: искры живут секунды, и поток держится сменой, а не
  /// числом. Предел стоит затем, чтобы просадка кадров не наматывала их
  /// без конца.
  static const maxCount = 900;

  /// Сколько рождается в секунду. Портал — это густо: редкий поток читается
  /// не кольцом искр, а грязью на обложке.
  static const rate = 600.0;

  /// Насколько поле шире обложки. В этой полосе искры и видны — на самой
  /// обложке они мешали бы её разглядывать.
  static const halo = 22.0;

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

  /// Двигает поток на [dt] секунд.
  ///
  /// Шаг ограничен сверху: после свёрнутого окна или просадки приходит
  /// секунда разом, и без предела искры прыгнули бы через полконтура.
  void advance(double dt) {
    if (size.isEmpty) return;
    final step = dt.clamp(0.0, 1 / 30);
    time += step;

    for (final spark in sparks) {
      spark.at = (spark.at + spark.speed * step) % 1.0;
      spark.drift += spark.driftSpeed * step;
      // Снос замедляется — искра выдыхается, а не улетает за экран.
      spark.driftSpeed *= 1 - 1.6 * step;
      spark.life -= step;
    }
    sparks.removeWhere((spark) => spark.life <= 0);

    _budget += rate * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      final life = _rand(0.4, 1.3);
      sparks.add(
        PortalSpark(
          at: _random.nextDouble(),
          // Против часовой у трети — встречные искры не дают потоку
          // выглядеть нарисованной каруселью.
          speed: _rand(0.3, 0.95) * (_random.nextDouble() < 0.3 ? -1 : 1),
          // Рождаются у самого края обложки и уходят наружу.
          drift: _rand(-2, 2),
          driftSpeed: _rand(6, halo * 1.6),
          life: life,
          maxLife: life,
        ),
      );
    }
    if (_budget > rate) _budget = rate;
  }

  /// Точка на контуре по доле пути и сносу наружу.
  ///
  /// Контур — прямоугольник обложки со скруглением, поэтому идём по
  /// сторонам: доля пути раскладывается на сторону и место на ней.
  Offset pointAt(double at, double drift) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return Offset.zero;

    final t = at % 1.0;
    final half = w + h;
    final along = t * half * 2;

    late Offset base;
    late Offset outward;
    if (along < w) {
      base = Offset(along, 0);
      outward = const Offset(0, -1);
    } else if (along < w + h) {
      base = Offset(w, along - w);
      outward = const Offset(1, 0);
    } else if (along < w * 2 + h) {
      base = Offset(w - (along - w - h), h);
      outward = const Offset(0, 1);
    } else {
      base = Offset(0, h - (along - w * 2 - h));
      outward = const Offset(-1, 0);
    }
    return base + outward * drift;
  }

  /// След искры: где она была на протяжении [seconds] до этого кадра.
  ///
  /// Считается обратным ходом по её же скорости, а не рисуется отрезком
  /// наугад: у искры, идущей навстречу потоку и уносимой наружу, хвост
  /// изгибается — из этого изгиба шлейф и читается шлейфом.
  List<Offset> trail(
    PortalSpark spark, {
    double seconds = 0.13,
    int steps = 7,
  }) {
    final points = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final back = seconds * i / steps;
      // Хвост не уходит внутрь: искра пришла с кромки, а не из-под
      // обложки, и упёршийся в кромку хвост читается именно так.
      points.add(
        pointAt(
          spark.at - spark.speed * back,
          math.max(0, spark.drift - spark.driftSpeed * back),
        ),
      );
    }
    return points;
  }
}

/// Обёртка, рисующая искры поверх плитки.
class PortalSparks extends StatefulWidget {
  const PortalSparks({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<PortalSparks> createState() => PortalSparksState();
}

class PortalSparksState extends State<PortalSparks> {
  /// Поток живёт в состоянии, а не в рисовальщике: тот создаётся заново при
  /// каждой пересборке плитки — а плитка пересобирается на каждом переводе
  /// выделения. Искры начинали бы с чистого места и вспыхивали заново.
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
        clipBehavior: Clip.none,
        children: [
          // Под обложкой: то, что попало на неё, скрыто, и остаётся ровно
          // кольцо вокруг — а не рябь поверх картинки.
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
    // Контур считается по обложке, а слой шире её на кайму: снос наружу
    // выносит искры именно туда, где им и место — вокруг, а не поверх.
    canvas.translate(halo, halo);

    // Свечение по краю: без него искры висят в пустоте, а с ним читаются
    // как один горящий контур.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & inner, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.portalRim.withValues(alpha: dark ? 0.55 : 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
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
            alpha: fade * along * along * (dark ? 0.95 : 0.75),
          )
          ..strokeWidth = 0.5 + 1.9 * along * fade;
        canvas.drawLine(points[i + 1], points[i], paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
