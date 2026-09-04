import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A repaint clock that never rebuilds retained content on animation frames.
class DecorativeMotion extends StatefulWidget {
  const DecorativeMotion({
    super.key,
    required this.enabled,
    required this.builder,
    this.child,
  });
  final bool enabled;
  final Widget? child;
  final Widget Function(BuildContext, ValueListenable<double>, Widget?) builder;

  @override
  State<DecorativeMotion> createState() => DecorativeMotionState();
}

class DecorativeMotionState extends State<DecorativeMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _time = ValueNotifier(0.0);
  late final Ticker _ticker = createTicker(_tick);
  Duration? _previous;
  bool _foreground = true;
  bool get isAnimating => _ticker.isActive && !_ticker.muted;
  double get time => _time.value;

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
    _sync();
  }

  @override
  void didUpdateWidget(DecorativeMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final run =
        widget.enabled &&
        !reduced &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (run && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    }
    if (!run && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
    if (!widget.enabled || reduced) _time.value = 0;
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
    _time.value += dt;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _time, widget.child);
}
