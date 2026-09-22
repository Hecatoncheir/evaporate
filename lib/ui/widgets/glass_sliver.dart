import 'package:flutter/widgets.dart';

import 'glass_surface.dart';
import 'sliver_glass_clip.dart';

/// Стекло [GlassSurface], но сливером: под длинный ленивый список.
///
/// Коробкой такой список не обернуть — он перестал бы быть ленивым и
/// строил бы все строки разом. Облик тот же до тени: заливка и тени —
/// из [GlassSurface.decorationOf], обрезка и размытие — из
/// [SliverGlassClip].
class GlassSliver extends StatelessWidget {
  const GlassSliver({
    super.key,
    required this.sliver,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.opacity,
  });

  final Widget sliver;
  final double radius;
  final EdgeInsets padding;
  final double? opacity;

  @override
  Widget build(BuildContext context) => SliverGlassClip(
    radius: radius,
    blur: GlassSurface.blur,
    sliver: DecoratedSliver(
      decoration: GlassSurface.decorationOf(
        context,
        radius: radius,
        opacity: opacity,
      ),
      sliver: SliverPadding(padding: padding, sliver: sliver),
    ),
  );
}
