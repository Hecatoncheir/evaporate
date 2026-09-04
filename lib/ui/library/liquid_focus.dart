import 'dart:math' as math;
import 'dart:ui';

/// Shared focus, not independent flashes on individual tiles. Geometry is
/// sampled in viewport coordinates, so scrolling and window resizing agree.
class LiquidFocus {
  Rect? from;
  Rect? target;
  Object? identity;
  double progress = 1;

  Rect? get current => target == null
      ? null
      : Rect.lerp(
          from ?? target,
          target,
          1 - math.pow(1 - progress, 3).toDouble(),
        );

  void update(Rect? rect, Object? id, {bool animate = true}) {
    if (rect == null) {
      from = target = null;
      identity = null;
      progress = 1;
      return;
    }
    if (id != identity) {
      from = current ?? rect;
      target = rect;
      identity = id;
      progress = animate && from != rect ? 0 : 1;
    } else {
      // Scroll/layout updates move the destination, never restart the morph.
      target = rect;
      if (progress == 1) from = rect;
    }
  }

  void step(double seconds) {
    if (seconds.isFinite && seconds > 0) {
      progress = (progress + seconds.clamp(0, 1 / 30) / 0.56).clamp(0, 1);
    }
  }
}
