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
    required this.life,
    required this.span,
  });

  /// Доля пути по периметру, 0..1.
  double at;

  /// Долей периметра в секунду. Разброс скоростей и делает поток потоком:
  /// с одинаковой все искры выглядели бы спицами колеса.
  final double speed;

  /// Насколько искра отходит наружу от контура, в точках.
  double drift;

  /// Сколько ей осталось, в секундах.
  double life;

  /// Длина хвоста долей периметра — из неё рисуется штрих.
  final double span;
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
  static const maxCount = 220;

  /// Сколько рождается в секунду.
  static const rate = 140.0;

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
      // Снос наружу замедляется — искра выдыхается, а не улетает.
      spark.drift += spark.drift * step * 1.2 + step * 6;
      spark.life -= step;
    }
    sparks.removeWhere((spark) => spark.life <= 0);

    _budget += rate * step;
    while (_budget >= 1 && sparks.length < maxCount) {
      _budget -= 1;
      sparks.add(
        PortalSpark(
          at: _random.nextDouble(),
          // Против часовой у трети — встречные искры не дают потоку
          // выглядеть нарисованной каруселью.
          speed: _rand(0.25, 0.75) * (_random.nextDouble() < 0.3 ? -1 : 1),
          drift: _rand(-1.5, 1.5),
          life: _rand(0.35, 1.1),
          span: _rand(0.004, 0.02),
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

    return DecorativeMotion(
      enabled: true,
      child: widget.child,
      builder: (context, clock, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          Positioned.fill(
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
    if (size.isEmpty) return;
    field.resize(size);
    field.advance(clock.value - field.lastFrame);
    field.lastFrame = clock.value;

    // Свечение по краю: без него искры висят в пустоте, а с ним читаются
    // как один горящий контур.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.portalRim.withValues(alpha: dark ? 0.5 : 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      rim,
    );

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      // Складываем свет, а не закрашиваем: пересекающиеся искры должны
      // разгораться, как искры, а не гасить друг друга.
      ..blendMode = BlendMode.plus;

    for (final spark in field.sparks) {
      final fade = spark.life.clamp(0.0, 1.0);
      final head = field.pointAt(spark.at, spark.drift);
      final tail = field.pointAt(
        spark.at - spark.span * spark.speed.sign,
        spark.drift * 0.4,
      );
      paint
        ..color = Color.lerp(
          AppColors.portalSpark,
          AppColors.portalRim,
          1 - fade,
        )!.withValues(alpha: fade * (dark ? 0.9 : 0.7))
        ..strokeWidth = 1.6 * fade + 0.4;
      canvas.drawLine(tail, head, paint);
    }
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.clock != clock || old.dark != dark || old.field != field;
}
