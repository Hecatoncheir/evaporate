import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid_geometry.dart';

/// Сама заливка. Формы не знает — берёт готовый контур у геометрии.
class LiquidPainter extends CustomPainter {
  LiquidPainter({
    required this.geometry,
    required this.color,
    required this.resting,
  }) : super(repaint: geometry.repaint);

  final LiquidGeometry geometry;
  final Color color;

  /// Остаётся ли капля лежать на месте после перехода. Нет — значит она
  /// только провожает взгляд и гаснет к концу пути.
  final bool resting;

  @override
  void paint(Canvas canvas, Size size) {
    final path = geometry.path();
    if (path == null) return;
    final t = geometry.progress;
    if (!resting && t >= 1) return;
    final paint = Paint()..color = color;
    if (!resting) {
      paint.color = color.withValues(alpha: color.a * math.sin(math.pi * t));
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiquidPainter oldDelegate) => true;
}
