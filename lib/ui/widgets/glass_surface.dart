import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Унифицированная аппаратная поверхность: матовая заливка, тонкий световой
/// кант и небольшая глубина, как у панели из окрашенного алюминия.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.opacity,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? opacity;
  final bool shadow;

  /// Размытие подложки под стеклом.
  static const blur = 16.0;

  /// Заливка, отлив, кант и тени стекла — без размытия и обрезки.
  ///
  /// Отдельно от виджета, потому что стекло бывает и сливером
  /// (`GlassSliver`): ленивый список в коробку не обернуть, а облик у двух
  /// карточек рядом обязан быть один.
  static BoxDecoration decorationOf(
    BuildContext context, {
    double radius = 24,
    double? opacity,
    bool shadow = true,
  }) {
    final colors = context.colors;
    final surface = HardwareSurfaceTheme.of(context);
    final glass = GlassSurfaceTheme.of(context);
    final effectiveOpacity = opacity ?? glass.fillOpacity;
    return BoxDecoration(
      color: colors.surface.withValues(alpha: effectiveOpacity),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.surface.withValues(
            alpha: glass.sheenTopOpacity ?? effectiveOpacity,
          ),
          colors.surfaceHigh.withValues(alpha: glass.sheenBottomOpacity),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colors.textPrimary.withValues(alpha: glass.rimOpacity),
      ),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: surface.shadow,
                blurRadius: 24,
                offset: const Offset(10, 14),
              ),
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: glass.counterLightOpacity,
                ),
                blurRadius: 12,
                offset: const Offset(-5, -5),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: decorationOf(
            context,
            radius: radius,
            opacity: opacity,
            shadow: shadow,
          ),
          child: Material(
            color: AppColors.transparent,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}
