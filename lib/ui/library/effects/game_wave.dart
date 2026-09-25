import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/decorative_motion.dart';
import '../../widgets/pointer_trail.dart';

/// Неоновое поле из двадцати шести линий, нарисованное средствами Flutter.
/// Образец: https://hecatoncheir.github.io/ (#wave).
///
/// Вздутие волны тянется за курсором оболочки (`PointerTrail`): там же он
/// и сглажен — одними часами на все украшения, а не своими в художнике.
/// Художник создаётся заново при каждой пересборке того, что под ним
/// нарисовано, и сглаживание в нём начиналось бы с середины на каждом
/// переводе выделения с игры на игру.
class GameWave extends StatefulWidget {
  const GameWave({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<GameWave> createState() => GameWaveState();
}

class GameWaveState extends State<GameWave> {
  static const _center = Offset(0.5, 0.5);

  final _pointer = ValueNotifier(_center);
  PointerTrail? _trail;

  /// Курсор в долях самой волны: за ним тянется вздутие.
  @visibleForTesting
  ValueListenable<Offset> get pointer => _pointer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trail = PointerTrail.maybeOf(context);
    if (trail == _trail) return;
    _trail?.removeListener(_follow);
    _trail = trail?..addListener(_follow);
  }

  /// Курсор оболочки — в доли волны: вздутие встаёт там, где курсор над
  /// волной, а не там, где он над окном.
  void _follow() {
    final trail = _trail;
    final box = context.findRenderObject();
    if (!widget.enabled || trail == null || box is! RenderBox) return;
    if (!box.hasSize || box.size.isEmpty) return;
    final local = trail.localIn(box, trail.value);
    if (local == null) return;
    _pointer.value = Offset(
      local.dx / box.size.width,
      local.dy / box.size.height,
    );
  }

  @override
  void dispose() {
    _trail?.removeListener(_follow);
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive =
        widget.enabled && !MediaQuery.disableAnimationsOf(context);
    return DecorativeMotion(
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
                      effects: EffectsPalette.of(context),
                      interactive: interactive,
                    ),
                  ),
                ),
              ),
            ),
          child!,
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(
    this.clock,
    this.pointer, {
    required this.effects,
    required this.interactive,
  }) : super(repaint: Listenable.merge([clock, pointer]));
  final ValueListenable<double> clock;
  final ValueListenable<Offset> pointer;
  final EffectsPalette effects;
  final bool interactive;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final time = clock.value * 0.16;
    final target = interactive ? pointer.value : const Offset(0.5, 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final gradient = LinearGradient(
      colors: effects.waveColors,
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
        alpha: (0.10 + 0.30 * math.sin(math.pi * k)) * effects.waveStrength,
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
      oldDelegate.effects != effects ||
      oldDelegate.interactive != interactive ||
      oldDelegate.clock != clock ||
      oldDelegate.pointer != pointer;
}
