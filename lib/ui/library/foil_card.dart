import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Перспектива, голографический перелив и упругая деформация — три
/// независимых эффекта, каждый со своим выключателем в настройках.
///
/// Тикер крутится только у активной карточки и у той, что ещё возвращается
/// в покой: иначе вся сетка обложек анимировалась бы разом.
class FoilCard extends StatefulWidget {
  const FoilCard({
    super.key,
    required this.active,
    required this.enabled,
    this.foilEnabled = true,
    this.tiltEnabled = true,
    this.distortionEnabled = false,
    required this.child,
  });

  final bool active;
  final bool enabled;
  final bool foilEnabled, tiltEnabled, distortionEnabled;
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
    final enabled =
        widget.enabled &&
        (widget.foilEnabled || widget.tiltEnabled || widget.distortionEnabled);
    _motion.foil = widget.enabled && widget.foilEnabled;
    _motion.distortion = enabled && !reduced && widget.distortionEnabled;
    if (!enabled || reduced) {
      _motion.strength = enabled && widget.active ? 1 : 0;
      _motion.tilt = false;
      _motion.phase = 0;
    } else {
      _motion.tilt = widget.tiltEnabled;
    }
    _motion.changed();
    final run =
        enabled &&
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
  bool foil = true;
  bool distortion = false;
  double get amount => Curves.easeInOut.transform(strength);
  Matrix4 get perspective {
    final matrix = Matrix4.identity();
    if (strength == 0) return matrix;
    if (tilt) {
      matrix
        ..setEntry(3, 2, 0.0015)
        ..rotateX(math.sin(phase) * 0.11 * amount)
        ..rotateY(math.sin(phase + math.pi / 3) * 0.16 * amount);
    }
    if (distortion) {
      // Пробегающее сжатие в момент прихода фокуса и мягкое покачивание
      // следом. Масштабы взаимно обратны: площадь сохраняется, и сетка от
      // деформации не разъезжается.
      final pulse = math.sin(strength * math.pi * 2) * (1 - strength);
      final stretch = 1 + pulse * 0.065 + math.sin(phase * 2) * 0.012 * amount;
      final liquid = Matrix4.identity()
        ..setEntry(0, 0, stretch)
        ..setEntry(1, 1, 1 / stretch)
        ..setEntry(
          0,
          1,
          pulse * 0.035 + math.sin(phase * 1.7) * 0.009 * amount,
        );
      matrix.multiply(liquid);
    }
    return matrix;
  }

  void changed() => notifyListeners();
}

class _FoilScope extends InheritedWidget {
  const _FoilScope({required this.motion, required super.child});
  final _FoilMotion motion;
  @override
  bool updateShouldNotify(_FoilScope oldWidget) => motion != oldWidget.motion;
}

/// Накладывается на обложку: значки состояния и полоса загрузки остаются
/// поверх перелива, иначе их было бы не прочитать.
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
