import 'package:flutter/material.dart';

import 'liquid_geometry.dart';
import 'liquid_ink_scope.dart';

/// Держит подпись и значок читаемыми, пока под ними ещё уходит капля.
/// Перерисовывается только это маленькое поддерево, а не всё вокруг.
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
    final geometry = LiquidInkScope.maybeOf(context);
    if (geometry == null) return widget.child;
    return AnimatedBuilder(
      animation: geometry.repaint,
      child: KeyedSubtree(key: _anchor, child: widget.child),
      builder: (context, child) {
        final color = _covered(geometry)
            ? widget.selectedColor
            : widget.normalColor;
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

  /// Накрыта ли подпись каплей прямо сейчас — по её середине.
  bool _covered(LiquidGeometry geometry) {
    final box = _anchor.currentContext?.findRenderObject();
    final viewport = geometry.viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    if (viewport is! RenderBox || !viewport.hasSize) return false;
    final path = geometry.path();
    if (path == null) return false;
    return path.contains(
      MatrixUtils.transformPoint(
        box.getTransformTo(viewport),
        box.size.center(Offset.zero),
      ),
    );
  }
}
