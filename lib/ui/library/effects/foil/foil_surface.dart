import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'foil_motion.dart';
import 'foil_scope.dart';

/// Накладывается на обложку: значки состояния и полоса загрузки остаются
/// поверх перелива, иначе их было бы не прочитать.
class FoilSurface extends StatelessWidget {
  const FoilSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context
        .dependOnInheritedWidgetOfExactType<FoilScope>()
        ?.motion;
    if (motion == null) return child;
    return CustomPaint(
      foregroundPainter: _FoilPainter(motion),
      child: RepaintBoundary(child: child),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(this.motion) : super(repaint: motion);
  final FoilMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (!motion.foil || motion.strength == 0 || size.isEmpty) return;
    final bounds = Offset.zero & size;
    final shift = math.sin(motion.phase);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.4 + shift, -1),
          end: Alignment(1.4 + shift, 1),
          colors: libraryInkColors
              .map((c) => c.withValues(alpha: 0.24 * motion.amount))
              .toList(),
          tileMode: TileMode.mirror,
          transform: GradientRotation(math.sin(motion.phase + 0.6) * 0.45),
        ).createShader(bounds),
    );
    // Узкий блик идёт тем же циклом, что и перспектива: разойдись они,
    // отражение перестало бы читаться как отражение.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.5 + shift * 1.8, -0.7),
          end: Alignment(0.5 + shift * 1.8, 0.7),
          colors: [
            AppColors.transparent,
            AppColors.foilHighlight.withValues(alpha: 0.25 * motion.amount),
            AppColors.transparent,
          ],
          stops: const [0.3, 0.5, 0.7],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_FoilPainter oldDelegate) => motion != oldDelegate.motion;
}
