import 'package:flutter/material.dart';

import 'liquid_geometry.dart';

/// Раздаёт геометрию капли вниз по дереву: подписи и значки, которых она
/// накрывает, лежат где угодно внутри удерживаемого содержимого.
class LiquidInkScope extends InheritedWidget {
  const LiquidInkScope({
    super.key,
    required this.geometry,
    required super.child,
  });

  final LiquidGeometry geometry;

  static LiquidGeometry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidInkScope>()?.geometry;

  @override
  bool updateShouldNotify(LiquidInkScope oldWidget) =>
      geometry != oldWidget.geometry;
}
