import 'package:flutter/material.dart';

import 'liquid_geometry.dart';

/// Сама заливка. Формы не знает — берёт готовый контур у геометрии.
class LiquidPainter extends CustomPainter {
  LiquidPainter({required this.geometry, required this.color})
    : super(repaint: geometry.repaint);

  final LiquidGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = geometry.path();
    if (path == null) return;
    final paint = Paint()..color = color;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiquidPainter oldDelegate) => true;
}
