import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'decoration_clock.dart';

/// Часы перерисовки: гонят кадры анимации, ни разу не пересобирая то,
/// что под ними нарисовано.
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
    with SingleTickerProviderStateMixin, DecorationClock {
  final _time = ValueNotifier(0.0);

  @visibleForTesting
  double get time => _time.value;

  @override
  bool get wantsFrames => widget.enabled;

  @override
  void syncClock() {
    super.syncClock();
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _time.value = 0;
    }
  }

  @override
  void onFrame(double dt) => _time.value += dt;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _time, widget.child);
}
