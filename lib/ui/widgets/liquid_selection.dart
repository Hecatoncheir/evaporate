import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A retained-content selection layer. Only its ink morphs, never labels,
/// artwork or hit targets. The neck approximates a thresholded gooey mask
/// with vector curves, avoiding backdrop filters that alter theme colours.
class LiquidSelection extends StatefulWidget {
  const LiquidSelection({
    super.key,
    required this.targetKey,
    required this.color,
    required this.child,
    this.enabled = true,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
    this.resting = true,
  });

  final GlobalKey? Function() targetKey;
  final Color color;
  final Widget child;
  final bool enabled, resting;
  final double radius;
  final EdgeInsets padding;

  @override
  State<LiquidSelection> createState() => LiquidSelectionState();
}

class LiquidSelectionState extends State<LiquidSelection>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _viewport = GlobalKey();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  final _geometry = ValueNotifier<int>(0);
  late final _repaint = Listenable.merge([_animation, _geometry]);
  GlobalKey? _identity;
  Rect? _from, _to;
  bool _queued = false;
  bool _foreground = true;
  bool _allowed = false;

  bool get isAnimating => _animation.isAnimating;
  Rect? get targetRect => _to;

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
  void didUpdateWidget(LiquidSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _allowed =
        widget.enabled &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!_allowed) _animation.value = 1;
    _scheduleMeasure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _scheduleMeasure() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final viewport = _viewport.currentContext?.findRenderObject();
    final identity = widget.targetKey();
    final target = identity?.currentContext?.findRenderObject();
    Rect? rect;
    if (viewport is RenderBox &&
        viewport.hasSize &&
        target is RenderBox &&
        target.attached &&
        target.hasSize) {
      final candidate = widget.padding.inflateRect(
        MatrixUtils.transformRect(
          target.getTransformTo(viewport),
          Offset.zero & target.size,
        ),
      );
      if (candidate.overlaps(Offset.zero & viewport.size)) rect = candidate;
    }
    if (rect == _to && identity == _identity) return;
    final previous = _to;
    final canTravel =
        _allowed &&
        previous != null &&
        rect != null &&
        identity != _identity &&
        _identity?.currentContext != null;
    _from = canTravel
        ? Rect.lerp(_from ?? previous, previous, _animation.value)
        : rect;
    _to = rect;
    _identity = identity;
    if (canTravel) {
      _animation.forward(from: 0);
    } else {
      // Layout, zoom, scrolling and removed items are not selection changes.
      _animation.value = 1;
    }
    _geometry.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    _geometry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return false;
        },
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleMeasure();
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleMeasure();
              return Stack(
                key: _viewport,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _LiquidPainter(this, _repaint),
                        ),
                      ),
                    ),
                  ),
                  _LiquidInkScope(
                    state: this,
                    child: SizeChangedLayoutNotifier(child: widget.child),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _LiquidInkScope extends InheritedWidget {
  const _LiquidInkScope({required this.state, required super.child});
  final LiquidSelectionState state;
  @override
  bool updateShouldNotify(_LiquidInkScope oldWidget) =>
      state != oldWidget.state;
}

/// Keep a label/icon readable even while the departing lobe is still under it.
/// Only this small foreground subtree rebuilds, not the surrounding content.
class LiquidSelectionInk extends StatefulWidget {
  const LiquidSelectionInk({
    super.key,
    required this.normalColor,
    required this.selectedColor,
    required this.child,
  });
  final Color normalColor, selectedColor;
  final Widget child;
  @override
  State<LiquidSelectionInk> createState() => _LiquidSelectionInkState();
}

class _LiquidSelectionInkState extends State<LiquidSelectionInk> {
  final _anchor = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final state = context
        .dependOnInheritedWidgetOfExactType<_LiquidInkScope>()
        ?.state;
    if (state == null) return widget.child;
    return AnimatedBuilder(
      animation: state._repaint,
      child: KeyedSubtree(key: _anchor, child: widget.child),
      builder: (context, child) {
        final box = _anchor.currentContext?.findRenderObject();
        final viewport = state._viewport.currentContext?.findRenderObject();
        final to = state._to;
        var covered = false;
        if (to != null &&
            box is RenderBox &&
            box.hasSize &&
            viewport is RenderBox &&
            viewport.hasSize) {
          final centre = MatrixUtils.transformPoint(
            box.getTransformTo(viewport),
            box.size.center(Offset.zero),
          );
          covered = liquidSelectionPath(
            state._from ?? to,
            to,
            state._animation.value,
            state.widget.radius,
          ).contains(centre);
        }
        final color = covered ? widget.selectedColor : widget.normalColor;
        return IconTheme.merge(
          data: IconThemeData(color: color),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: color),
            child: child!,
          ),
        );
      },
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter(this.state, Listenable repaint) : super(repaint: repaint);
  final LiquidSelectionState state;

  @override
  void paint(Canvas canvas, Size size) {
    final to = state._to;
    if (to == null) return;
    final t = state._animation.value;
    final widget = state.widget;
    if (!widget.resting && t >= 1) return;
    final paint = Paint()..color = widget.color;
    if (!widget.resting) {
      paint.color = widget.color.withValues(
        alpha: widget.color.a * math.sin(math.pi * t),
      );
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      liquidSelectionPath(state._from ?? to, to, t, widget.radius),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidPainter oldDelegate) => true;
}

/// Two rounded lobes exchange volume through a concave, pinching neck.
/// Exposed for deterministic geometry tests and mid-transition previews.
Path liquidSelectionPath(Rect from, Rect to, double progress, double radius) {
  Path rounded(Rect rect) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  final t = progress.clamp(0.0, 1.0);
  if (t == 0) return rounded(from);
  if (t == 1 || from == to) return rounded(to);
  final delta = to.center - from.center;
  final horizontal = delta.dx.abs() >= delta.dy.abs();
  final extent = horizontal
      ? math.max(from.width, to.width)
      : math.max(from.height, to.height);
  // Distant jumps travel as one drop, without drawing a ribbon across a page.
  if (delta.distance > extent * 2.5) {
    return rounded(Rect.lerp(from, to, Curves.easeInOutCubic.transform(t))!);
  }
  Rect scale(Rect rect, double factor) => Rect.fromCenter(
    center: rect.center,
    width: rect.width * factor,
    height: rect.height * factor,
  );
  final a = scale(from, 1 - Curves.easeInCubic.transform(t));
  final b = scale(to, Curves.easeOutCubic.transform(t));
  var path = Path.combine(PathOperation.union, rounded(a), rounded(b));
  Rect axisRect(Rect r) =>
      horizontal ? r : Rect.fromLTRB(r.top, r.left, r.bottom, r.right);
  var left = axisRect(a);
  var right = axisRect(b);
  if (left.center.dx > right.center.dx) {
    final swap = left;
    left = right;
    right = swap;
  }
  final gap = right.left - left.right;
  if (gap <= 0) return path;
  final x1 = left.right - math.min(radius, left.width * 0.15);
  final x2 = right.left + math.min(radius, right.width * 0.15);
  final y1 = left.center.dy;
  final y2 = right.center.dy;
  final h1 = left.height * 0.32;
  final h2 = right.height * 0.32;
  final mx = (x1 + x2) / 2;
  final my = (y1 + y2) / 2;
  final neck = math.min(h1, h2) * 0.42 * math.sin(math.pi * t);
  Offset point(double x, double y) => horizontal ? Offset(x, y) : Offset(y, x);
  final bridge = Path();
  void move(double x, double y) {
    final p = point(x, y);
    bridge.moveTo(p.dx, p.dy);
  }

  void line(double x, double y) {
    final p = point(x, y);
    bridge.lineTo(p.dx, p.dy);
  }

  void curve(double ax, double ay, double bx, double by, double cx, double cy) {
    final a = point(ax, ay), b = point(bx, by), c = point(cx, cy);
    bridge.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
  }

  move(x1, y1 - h1);
  curve(x1 + gap * 0.25, y1 - h1, mx - gap * 0.18, my - neck, mx, my - neck);
  curve(mx + gap * 0.18, my - neck, x2 - gap * 0.25, y2 - h2, x2, y2 - h2);
  line(x2, y2 + h2);
  curve(x2 - gap * 0.25, y2 + h2, mx + gap * 0.18, my + neck, mx, my + neck);
  curve(mx - gap * 0.18, my + neck, x1 + gap * 0.25, y1 + h1, x1, y1 + h1);
  bridge.close();
  path = Path.combine(PathOperation.union, path, bridge);
  return path;
}
