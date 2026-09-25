import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// Светодиод состояния: точка с ореолом, которая дышит, пока что-то идёт.
///
/// Ровно горящая точка и точка рядом с надписью «готово» несут одно и то
/// же; дышащая — говорит, что прибор работает **сейчас**. Поэтому [alive]
/// включают только там, где есть что показывать.
class PulseDot extends StatelessWidget {
  const PulseDot({
    super.key,
    required this.color,
    this.size = 8,
    this.alive = true,
  });

  final Color color;
  final double size;
  final bool alive;

  @override
  Widget build(BuildContext context) {
    // Ореол — часть ночного корпуса; на светлом он выглядел бы грязью,
    // поэтому днём остаётся одна точка.
    final halo = context.colors.glow.a > 0;
    final dot = SizedBox(
      width: size * 2.4,
      height: size * 2.4,
      child: alive
          ? DecorativeMotion(
              enabled: true,
              builder: (context, clock, _) => CustomPaint(
                painter: _PulsePainter(clock: clock, color: color, halo: halo),
              ),
            )
          : CustomPaint(
              painter: _PulsePainter(clock: null, color: color, halo: halo),
            ),
    );
    return ExcludeSemantics(child: dot);
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.clock, required this.color, required this.halo})
    : super(repaint: clock);

  final ValueListenable<double>? clock;
  final Color color;
  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2.4 / 2;
    // Полный цикл — две с половиной секунды: пульс медленнее сердца, иначе
    // светодиод торопит там, где торопиться некуда.
    final phase = clock == null
        ? 1.0
        : 0.55 + 0.45 * (0.5 + 0.5 * math.sin(clock!.value * 2.5));

    if (halo) {
      canvas.drawCircle(
        center,
        radius * (2.0 + phase),
        Paint()
          ..color = color.withValues(alpha: 0.18 * phase)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.45 + 0.55 * phase),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.halo != halo ||
      oldDelegate.clock != clock;
}
