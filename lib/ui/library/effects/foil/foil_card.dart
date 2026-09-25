import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/decoration_clock.dart';
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
    with SingleTickerProviderStateMixin, DecorationClock {
  final _motion = FoilMotion();

  @visibleForTesting
  Matrix4 get perspective => _motion.perspective;

  bool get _enabled =>
      widget.enabled &&
      (widget.foilEnabled || widget.tiltEnabled || widget.distortionEnabled);

  @override
  bool get wantsFrames => _enabled && (widget.active || _motion.strength > 0);

  /// Приводит облик карточки в соответствие с настройками и обстановкой, а
  /// затем — часы.
  @override
  void syncClock() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enabled = _enabled;

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
    super.syncClock();
  }

  @override
  void onFrame(double dt) {
    _motion.strength = (_motion.strength + (widget.active ? dt : -dt) / 0.3)
        .clamp(0.0, 1.0);
    _motion.phase = (_motion.phase + dt * math.pi * 2 / 7) % (math.pi * 2);
    _motion.changed();
    // Вернулась в покой — часам больше незачем идти.
    if (!widget.active && _motion.strength == 0) super.syncClock();
  }

  @override
  void dispose() {
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
      transform: _motion.perspective,
      child: child,
    ),
  );
}
