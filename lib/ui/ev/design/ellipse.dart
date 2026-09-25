import 'package:flutter/widgets.dart';

/// `radial-gradient(rx% ry% at …)` из CSS: эллипс по сторонам коробки.
/// У Flutter радиальный градиент — круг по меньшей стороне; этот
/// переход растягивает его. Градиенту ставится `radius: 1`.
class EvEllipse extends GradientTransform {
  const EvEllipse(this.rx, this.ry, {this.center = const Alignment(0, 0)});

  /// Полуоси в долях ширины и высоты: 0.75 — это «75%».
  final double rx;
  final double ry;

  /// Тот же центр, что у градиента.
  final Alignment center;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final side = bounds.shortestSide;
    final c = center.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(rx * bounds.width / side, ry * bounds.height / side, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}
