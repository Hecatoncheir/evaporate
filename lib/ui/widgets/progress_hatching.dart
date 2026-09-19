import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'decorative_motion.dart';

/// Наклонные насечки, бегущие по заполненной части.
class ProgressHatching extends StatelessWidget {
  const ProgressHatching({super.key});

  @override
  Widget build(BuildContext context) => DecorativeMotion(
    enabled: true,
    builder: (context, clock, _) => CustomPaint(
      painter: _HatchPainter(clock: clock, color: AppColors.artSweep),
    ),
  );
}

class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.clock, required this.color})
    : super(repaint: clock);

  final ValueListenable<double> clock;
  final Color color;

  /// Шаг насечек и скорость их бега.
  static const _step = 14.0;
  static const _speed = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shift = (clock.value * _speed) % _step;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    for (var x = -size.height - _step; x < size.width + _step; x += _step) {
      final at = x - shift;
      canvas.drawLine(
        Offset(at + size.height, 0),
        Offset(at, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.clock != clock;
}
