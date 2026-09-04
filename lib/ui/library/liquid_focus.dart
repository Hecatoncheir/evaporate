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

  /// A wavy outline and a pinching Bezier neck joining two shrinking/growing
  /// drops. No image readback, full-screen blur or GPU-specific shader needed.
  Path outline(double time) {
    final end = target;
    if (end == null) return Path();
    if (progress >= 1 || from == null) return _drop(end.inflate(6), time, 1.2);
    final t = progress;
    final start = from!;
    final eased = 1 - math.pow(1 - t, 3).toDouble();
    final tail = Rect.fromCenter(
      center: Offset.lerp(start.center, end.center, t * t)!,
      width: start.width * (1 - t * 0.88) + 12,
      height: start.height * (1 - t * 0.88) + 12,
    );
    final head = Rect.fromCenter(
      center: Offset.lerp(start.center, end.center, eased)!,
      width: end.width * (0.12 + 0.88 * eased) + 12,
      height: end.height * (0.12 + 0.88 * eased) + 12,
    );
    final path = _drop(
      tail,
      time,
      5 * math.sin(t * math.pi),
      radius: 18 + tail.shortestSide * 0.3 * math.sin(t * math.pi),
    );
    path.addPath(
      _drop(
        head,
        time + 0.8,
        5 * math.sin(t * math.pi),
        radius: 18 + head.shortestSide * 0.2 * math.sin(t * math.pi),
      ),
      Offset.zero,
    );
    final delta = head.center - tail.center;
    if (delta.distance > 1) {
      final axis = delta / delta.distance;
      final normal = Offset(-axis.dy, axis.dx);
      final width =
          math.min(start.shortestSide, end.shortestSide) *
          0.28 *
          math.sin(t * math.pi);
      final a = tail.center;
      final b = head.center;
      final neck = Offset.lerp(a, b, 0.5)!;
      path.moveTo((a + normal * width).dx, (a + normal * width).dy);
      path.cubicTo(
        (neck + normal * width * 0.25).dx,
        (neck + normal * width * 0.25).dy,
        (neck + normal * width * 0.25).dx,
        (neck + normal * width * 0.25).dy,
        (b + normal * width).dx,
        (b + normal * width).dy,
      );
      path.lineTo((b - normal * width).dx, (b - normal * width).dy);
      path.cubicTo(
        (neck - normal * width * 0.25).dx,
        (neck - normal * width * 0.25).dy,
        (neck - normal * width * 0.25).dx,
        (neck - normal * width * 0.25).dy,
        (a - normal * width).dx,
        (a - normal * width).dy,
      );
      path.close();
    }
    return path;
  }

  Path _drop(Rect rect, double time, double amplitude, {double radius = 18}) {
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metric = base.computeMetrics().first;
    final path = Path();
    for (var i = 0; i < 100; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / 100)!;
      final normal = Offset(tangent.vector.dy, -tangent.vector.dx);
      final wave = math.sin(i / 100 * math.pi * 8 + time * 2.5) * amplitude;
      final point = tangent.position + normal * wave;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }
}
