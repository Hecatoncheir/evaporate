import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../widgets/frame_step.dart';
import '../../../widgets/window_visibility.dart';
import 'foil_motion.dart';
import 'foil_scope.dart';

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
  final _motion = FoilMotion();
  late final Ticker _ticker = createTicker(_tick);
  final _step = FrameStep();
  bool _visible = true;
  bool get isAnimating => _ticker.isActive && !_ticker.muted;
  Matrix4 get perspective => _motion.perspective;

  @override
  void initState() {
    super.initState();
    _visible = isWindowVisible(WidgetsBinding.instance.lifecycleState);
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

  /// Приводит анимацию карточки в соответствие с настройками и обстановкой.
  void _syncMotion() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enabled =
        widget.enabled &&
        (widget.foilEnabled || widget.tiltEnabled || widget.distortionEnabled);

    _motion.foil = widget.enabled && widget.foilEnabled;
    _motion.distortion = enabled && !reduced && widget.distortionEnabled;
    if (enabled && !reduced) {
      _motion.tilt = widget.tiltEnabled;
    } else {
      // Украшения выключены или система просит не двигаться: карточка
      // замирает, но подсветка выбранной остаётся — это не украшение,
      // а указание, что выбрано.
      _motion.strength = enabled && widget.active ? 1 : 0;
      _motion.tilt = false;
      _motion.phase = 0;
    }
    _motion.changed();

    _runTicker(enabled && !reduced && _worthAnimating);
  }

  /// Стоит ли гнать кадры прямо сейчас.
  ///
  /// Украшение не должно жечь батарею за спиной: в свёрнутом окне, на
  /// невидимом разделе и на неактивном маршруте часы стоят.
  bool get _worthAnimating =>
      _visible &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (widget.active || _motion.strength > 0);

  /// Пускает или останавливает часы перерисовки.
  ///
  /// Отсчёт прошлого кадра сбрасывается на обеих границах: после паузы он
  /// показывал бы шаг длиной во всю паузу.
  void _runTicker(bool run) {
    if (run == _ticker.isActive) return;
    _step.reset();
    if (run) {
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _step.next(elapsed);
    if (dt == null) return;
    _motion.strength = (_motion.strength + (widget.active ? dt : -dt) / 0.3)
        .clamp(0.0, 1.0);
    _motion.phase = (_motion.phase + dt * math.pi * 2 / 7) % (math.pi * 2);
    _motion.changed();
    if (!widget.active && _motion.strength == 0) _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = isWindowVisible(state);
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
    child: FoilScope(
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
