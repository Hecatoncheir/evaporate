import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/decorative_motion.dart';

/// The reference hero's 26-line neon field, rendered locally in Flutter.
/// Reference: https://hecatoncheir.github.io/ (#wave).
class GameWave extends StatefulWidget {
  const GameWave({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<GameWave> createState() => _GameWaveState();
}

class _GameWaveState extends State<GameWave> {
  final _pointer = ValueNotifier(const Offset(0.5, 0.5));
  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final reduced = MediaQuery.disableAnimationsOf(context);
      return MouseRegion(
        onHover: (event) {
          if (widget.enabled && !reduced && !size.isEmpty) {
            _pointer.value = Offset(
              event.localPosition.dx / size.width,
              event.localPosition.dy / size.height,
            );
          }
        },
        onExit: (_) => _pointer.value = const Offset(0.5, 0.5),
        child: DecorativeMotion(
          key: const ValueKey('detail-wave-motion'),
          enabled: widget.enabled,
          child: RepaintBoundary(child: widget.child),
          builder: (context, clock, child) => Stack(
            fit: StackFit.expand,
            children: [
              if (widget.enabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('detail-wave-paint'),
                        painter: _WavePainter(
                          clock,
                          _pointer,
                          context.colors.isDark,
                          widget.enabled && !reduced,
                        ),
                      ),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        ),
      );
    },
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.clock, this.pointer, this.dark, this.interactive)
    : super(repaint: Listenable.merge([clock, pointer]));
  final ValueListenable<double> clock;
  final ValueListenable<Offset> pointer;
  final bool dark, interactive;
  Offset _smoothed = const Offset(0.5, 0.5);
  double _lastTime = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final time = clock.value * 0.16;
    final dt = (clock.value - _lastTime).clamp(0.0, 1 / 30);
    _lastTime = clock.value;
    _smoothed = Offset.lerp(_smoothed, pointer.value, 1 - math.exp(-3.7 * dt))!;
    final target = interactive ? _smoothed : const Offset(0.5, 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final gradient = LinearGradient(
      colors: waveColors(dark),
      stops: const [0, 0.34, 0.68, 1],
    );
    paint.shader = gradient.createShader(Offset.zero & size);
    final amplitude = size.shortestSide * 0.055;
    final step = size.width > 900 ? 8.0 : 12.0;
    for (var i = 0; i < 26; i++) {
      final k = i / 25;
      final baseline = size.height * (0.47 + 0.30 * k);
      final phase = time + k * 1.9;
      paint.color = AppColors.waveHighlight.withValues(
        alpha: (0.10 + 0.30 * math.sin(math.pi * k)) * (dark ? 1 : 0.8),
      );
      final path = Path();
      for (var x = -step; x <= size.width + step; x += step) {
        final nx = x / size.width;
        final dx = nx - target.dx;
        final dy = baseline / size.height - target.dy;
        final bulge = math.exp(-(dx * dx * 9 + dy * dy * 4)) * amplitude * 2.4;
        final y =
            baseline +
            math.sin(nx * 6 + phase * 2.1) * amplitude +
            math.sin(nx * 11 - phase * 1.4 + k * 3) * amplitude * 0.45 +
            math.sin(nx * 2.3 + phase * 0.8) * amplitude * 0.7 -
            bulge;
        if (x == -step) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.interactive != interactive ||
      oldDelegate.clock != clock ||
      oldDelegate.pointer != pointer;
}
