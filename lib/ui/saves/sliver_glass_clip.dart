import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Обрезка по скруглению и размытие подложки вокруг сливера — то, что
/// стеклу-коробке дают `ClipRRect` и `BackdropFilter`.
///
/// У Flutter обоих нет в виде сливеров, а без них ленивый список на
/// стекле выглядел бы иначе соседней карточки: тени стекла видны только
/// сквозь заливку внутри скругления, и без обрезки ложились бы ореолом
/// снаружи.
///
/// Скругляется вся карта, а не её видимая часть: прокрученная наполовину
/// не должна закругляться о край окна.
class SliverGlassClip extends SingleChildRenderObjectWidget {
  const SliverGlassClip({
    super.key,
    required this.radius,
    required this.filter,
    required Widget sliver,
  }) : super(child: sliver);

  final double radius;

  /// Что стекло делает с подложкой — тот же фильтр, что у стекла-коробки
  /// (`GlassSurface.filterOf`).
  final ImageFilter filter;

  @override
  RenderSliverGlassClip createRenderObject(BuildContext context) =>
      RenderSliverGlassClip(radius: radius, filter: filter);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverGlassClip renderObject,
  ) {
    renderObject
      ..radius = radius
      ..filter = filter;
  }
}

class RenderSliverGlassClip extends RenderProxySliver {
  RenderSliverGlassClip({required this._radius, required this._filter});

  double get radius => _radius;
  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  ImageFilter get filter => _filter;
  ImageFilter _filter;
  set filter(ImageFilter value) {
    if (value == _filter) return;
    _filter = value;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipRRectLayer>();
  final _backdrop = LayerHandle<BackdropFilterLayer>();

  /// Скругление всей карты в координатах сливера: верх уехал за край на
  /// прокрученное, высота — полная.
  RRect get cardShape {
    final extent = child?.geometry?.scrollExtent ?? 0;
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        -constraints.scrollOffset,
        constraints.crossAxisExtent,
        extent,
      ),
      Radius.circular(_radius),
    );
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !child.geometry!.visible) {
      _clip.layer = null;
      _backdrop.layer = null;
      return;
    }
    // Вертикальная прокрутка вниз — единственная, где стекло сливером
    // нужно; в остальных осях прямоугольник карты считался бы иначе.
    assert(constraints.axis == Axis.vertical);
    assert(constraints.axisDirection == AxisDirection.down);
    final shape = cardShape;
    _clip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      shape.outerRect,
      shape,
      (context, offset) {
        final backdrop = _backdrop.layer ??= BackdropFilterLayer();
        backdrop.filter = _filter;
        context.pushLayer(backdrop, (context, offset) {
          final data = child.parentData! as SliverPhysicalParentData;
          context.paintChild(child, offset + data.paintOffset);
        }, offset);
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _backdrop.layer = null;
    super.dispose();
  }
}
