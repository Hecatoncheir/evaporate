import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// A rigid card with synchronized perspective and holographic reflection.
/// Only the active card (or one settling back) owns a running ticker.
class FoilCard extends StatefulWidget {
  const FoilCard({
    super.key,
    required this.active,
    required this.enabled,
    required this.child,
  });

  final bool active;
  final bool enabled;
  final Widget child;

  @override
  State<FoilCard> createState() => FoilCardState();
}

class FoilCardState extends State<FoilCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _motion = _FoilMotion();
  late final Ticker _ticker = createTicker(_tick);
  Duration? _previous;
  bool _foreground = true;
  bool get isAnimating => _ticker.isActive && !_ticker.muted;
  Matrix4 get perspective => _motion.perspective;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(FoilCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || reduced) {
      _motion.strength = widget.enabled && widget.active ? 1 : 0;
      _motion.tilt = false;
      _motion.phase = 0;
      _motion.changed();
    } else {
      _motion.tilt = true;
    }
    final run =
        widget.enabled &&
        !reduced &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        (widget.active || _motion.strength > 0);
    if (run && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  void _tick(Duration elapsed) {
    if (_previous != null && (elapsed - _previous!).inMicroseconds < 16000) {
      return;
    }
    final dt = _previous == null
        ? 1 / 60
        : ((elapsed - _previous!).inMicroseconds /
                  Duration.microsecondsPerSecond)
              .clamp(0.0, 1 / 30);
    _previous = elapsed;
    _motion.strength = (_motion.strength + (widget.active ? dt : -dt) / 0.3)
        .clamp(0.0, 1.0);
    _motion.phase = (_motion.phase + dt * math.pi * 2 / 7) % (math.pi * 2);
    _motion.changed();
    if (!widget.active && _motion.strength == 0) _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: _FoilScope(
      motion: _motion,
      child: RepaintBoundary(child: widget.child),
    ),
    builder: (_, child) => Transform(
      key: const ValueKey('foil-perspective'),
      alignment: Alignment.center,
      transform: perspective,
      child: child,
    ),
  );
}

class _FoilMotion extends ChangeNotifier {
  double phase = 0;
  double strength = 0;
  bool tilt = true;
  double get amount => Curves.easeInOut.transform(strength);
  Matrix4 get perspective {
    if (!tilt || strength == 0) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX(math.sin(phase) * 0.11 * amount)
      ..rotateY(math.sin(phase + math.pi / 3) * 0.16 * amount);
  }

  void changed() => notifyListeners();
}

class _FoilScope extends InheritedWidget {
  const _FoilScope({required this.motion, required super.child});
  final _FoilMotion motion;
  @override
  bool updateShouldNotify(_FoilScope oldWidget) => motion != oldWidget.motion;
}

/// Apply to the artwork; status badges and progress stay above the reflection.
class FoilSurface extends StatelessWidget {
  const FoilSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context
        .dependOnInheritedWidgetOfExactType<_FoilScope>()
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
  final _FoilMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (motion.strength == 0 || size.isEmpty) return;
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
    // Narrow specular streak follows the same cycle as the perspective.
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
