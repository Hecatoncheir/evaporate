import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/decorative_motion.dart';

/// Gold rim, a deep magenta centre and a slowly moving coloured reflection.
/// A real Material button retains keyboard/gamepad activation and semantics.
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.effects,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool effects, busy;

  @override
  Widget build(BuildContext context) => DecorativeMotion(
    key: const ValueKey('play-button-motion'),
    enabled: effects && onPressed != null,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white60,
        shadowColor: Colors.transparent,
        minimumSize: const Size(180, 56),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito Sans',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
      icon: Icon(
        busy ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
        size: 22,
      ),
      label: Text(label),
    ),
    builder: (context, clock, child) => RepaintBoundary(
      child: CustomPaint(
        painter: _PlayPainter(clock, onPressed != null),
        child: child,
      ),
    ),
  );
}

class _PlayPainter extends CustomPainter {
  _PlayPainter(this.clock, this.enabled) : super(repaint: clock);
  final ValueListenable<double> clock;
  final bool enabled;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    if (!enabled) {
      canvas.drawRRect(shape, Paint()..color = const Color(0xFF514453));
      return;
    }
    final phase = clock.value * math.pi / 5;
    final glow = Color.lerp(
      const Color(0xFFFFB900),
      const Color(0xFFDB16B8),
      (math.sin(phase) + 1) / 2,
    )!;
    canvas.drawRRect(
      shape.inflate(4),
      Paint()
        ..color = glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1, math.sin(phase) * 0.8),
          end: Alignment(1, -math.sin(phase) * 0.8),
          colors: const [
            Color(0xFFFFD51F),
            Color(0xFFFF9C20),
            Color(0xFFD91B9C),
            Color(0xFF8D24BC),
          ],
        ).createShader(rect),
    );
    // A dark central reflection keeps white text readable over the gold.
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0xF252164F), Color(0xC070175B), Color(0x0060175B)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFE55B), glow, const Color(0xFFFFCB22)],
          transform: GradientRotation(phase * 0.25),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) =>
      oldDelegate.enabled != enabled || oldDelegate.clock != clock;
}
