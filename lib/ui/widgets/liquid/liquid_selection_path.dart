import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Две скруглённые доли перетекают друг в друга через вогнутую перемычку.
///
/// Открыто наружу ради тестов геометрии и предпросмотра середины перехода:
/// на глаз такую форму не проверить, а числами — вполне.
Path liquidSelectionPath(Rect from, Rect to, double progress, double radius) {
  final t = progress.clamp(0.0, 1.0);
  if (t == 0) return _rounded(from, radius);
  if (t == 1 || from == to) return _rounded(to, radius);

  final delta = to.center - from.center;
  final horizontal = delta.dx.abs() >= delta.dy.abs();
  final extent = horizontal
      ? math.max(from.width, to.width)
      : math.max(from.height, to.height);
  // Дальний прыжок капля проделывает целиком, не растягиваясь лентой
  // через всю страницу.
  if (delta.distance > extent * 2.5) {
    final jump = Rect.lerp(from, to, Curves.easeInOutCubic.transform(t))!;
    return _rounded(jump, radius);
  }

  final a = _scaled(from, 1 - Curves.easeInCubic.transform(t));
  final b = _scaled(to, Curves.easeOutCubic.transform(t));
  final blobs = Path.combine(
    PathOperation.union,
    _rounded(a, radius),
    _rounded(b, radius),
  );

  final bridge = _bridge(a, b, horizontal: horizontal, radius: radius, t: t);
  if (bridge == null) return blobs;
  return Path.combine(PathOperation.union, blobs, bridge);
}

Path _rounded(Rect rect, double radius) =>
    Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

Rect _scaled(Rect rect, double factor) => Rect.fromCenter(
  center: rect.center,
  width: rect.width * factor,
  height: rect.height * factor,
);

/// Перемычка между долями; `null` — доли уже сошлись, и добавлять нечего.
///
/// Считается всегда вдоль горизонтали: поперечная ось на время расчёта
/// переворачивается и возвращается на место при записи точки. Иначе та же
/// дюжина формул была бы выписана дважды, с переставленными `x` и `y`, —
/// и разошлась бы при первой же правке.
Path? _bridge(
  Rect a,
  Rect b, {
  required bool horizontal,
  required double radius,
  required double t,
}) {
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
  if (gap <= 0) return null;

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
  return bridge;
}
