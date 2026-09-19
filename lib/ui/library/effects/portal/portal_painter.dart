import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'portal_renderer.dart';
import 'portal_spark_field.dart';

/// Шаг симуляции и отрисовка кадра. Часы приходят от `DecorativeMotion`.
class PortalPainter extends CustomPainter {
  PortalPainter({
    required this.clock,
    required this.field,
    required this.renderer,
    required this.blend,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final PortalSparkField field;
  final PortalRenderer renderer;
  final BlendMode blend;

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

    renderer.paint(canvas, field, blend: blend);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PortalPainter old) =>
      old.clock != clock ||
      old.blend != blend ||
      old.field != field ||
      old.renderer != renderer;
}
