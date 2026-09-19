import 'package:flutter/material.dart';

import '../theme.dart';

/// Перфорированная решётка — короткая визуальная подпись аппаратного стиля.
/// Она декоративна, поэтому не попадает в дерево доступности.
class HardwareGrille extends StatelessWidget {
  const HardwareGrille({super.key, this.width = 88, this.height = 46});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _GrillePainter(
          plate: context.colors.surfaceHigh,
          hole: HardwareSurfaceTheme.of(context).grilleHole,
          light: context.colors.primary,
        ),
      ),
    ),
  );
}

class _GrillePainter extends CustomPainter {
  const _GrillePainter({
    required this.plate,
    required this.hole,
    required this.light,
  });

  final Color plate;
  final Color hole;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = plate,
    );
    const gap = 8.0;
    final rows = (size.height / gap).floor();
    final columns = (size.width / gap).floor();
    final xInset = (size.width - (columns - 1) * gap) / 2;
    final yInset = (size.height - (rows - 1) * gap) / 2;
    final holePaint = Paint()..color = hole;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        canvas.drawCircle(
          Offset(xInset + column * gap, yInset + row * gap),
          2.05,
          holePaint,
        );
      }
    }
    canvas.drawCircle(
      Offset(size.width - 8, 8),
      3.2,
      Paint()
        ..color = light
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GrillePainter oldDelegate) =>
      oldDelegate.plate != plate ||
      oldDelegate.hole != hole ||
      oldDelegate.light != light;
}
