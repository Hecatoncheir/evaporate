import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bokeh_lava_gradient/bokeh_lava_gradient.dart';

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
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _LavaBackground(
                    enabled: effects && onPressed != null,
                    available: onPressed != null,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PlayFinish(clock, onPressed != null),
                ),
              ),
            ),
            child!,
          ],
        ),
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
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) =>
      oldDelegate.enabled != enabled || oldDelegate.clock != clock;
}

class _PlayFinish extends CustomPainter {
  _PlayFinish(this.clock, this.enabled) : super(repaint: clock);
  final ValueListenable<double> clock;
  final bool enabled;
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final phase = clock.value * math.pi / 5;
    final glow = Color.lerp(
      const Color(0xFFFFB900),
      const Color(0xFFDB16B8),
      (math.sin(phase) + 1) / 2,
    )!;
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
  bool shouldRepaint(_PlayFinish oldDelegate) =>
      oldDelegate.enabled != enabled || oldDelegate.clock != clock;
}

/// The package has no reduced-motion switch. Mount its ticker only when the
/// button is visible and motion is allowed; remounting also avoids a large
/// elapsed-time catch-up after TickerMode has muted a hidden page.
class _LavaBackground extends StatefulWidget {
  const _LavaBackground({required this.enabled, required this.available});
  final bool enabled, available;
  @override
  State<_LavaBackground> createState() => _LavaBackgroundState();
}

class _LavaBackgroundState extends State<_LavaBackground>
    with WidgetsBindingObserver {
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving =
        widget.enabled &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!widget.available) return const ColoredBox(color: Color(0xFF514453));
    if (!moving) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD51F), Color(0xFFD91B9C), Color(0xFF8D24BC)],
          ),
        ),
      );
    }
    return const BokehLavaGradient(
      baseColor: Color(0xFF862668),
      colors: [
        Color(0xFFFFD51F),
        Color(0xFFFF9C20),
        Color(0xFFE824AA),
        Color(0xFF9A38D3),
      ],
      blobCount: 10,
      speed: 1.2,
      blurStrength: 0.12,
      blobOpacity: 0.85,
      minBlobRadius: 0.55,
      maxBlobRadius: 1.15,
      lowResFactor: 0.75,
      targetFps: 30,
    );
  }
}
