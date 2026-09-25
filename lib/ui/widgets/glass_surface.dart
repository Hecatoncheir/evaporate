import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Унифицированная аппаратная поверхность: матовая заливка, тонкий световой
/// кант и небольшая глубина, как у панели из окрашенного алюминия.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.padding,
    this.opacity,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? opacity;
  final bool shadow;

  /// Что стекло делает с подложкой: размывает её, а размытое делает
  /// насыщеннее и темнее. Стекло собирает свет, поэтому под ним он гуще,
  /// чем рядом. Матрица — как `saturate()` и `brightness()` в CSS,
  /// светимость по Rec. 709.
  ///
  /// Отдельно от виджета, потому что стекло бывает и сливером: фильтр у
  /// двух карточек рядом обязан быть один.
  static ImageFilter filterOf(GlassSurfaceTheme glass) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = glass.backdropSaturation;
    final b = glass.backdropBrightness;
    return ImageFilter.compose(
      outer: ColorFilter.matrix([
        (lr + (1 - lr) * s) * b, (lg - lg * s) * b, (lb - lb * s) * b, 0, 0, //
        (lr - lr * s) * b, (lg + (1 - lg) * s) * b, (lb - lb * s) * b, 0, 0, //
        (lr - lr * s) * b, (lg - lg * s) * b, (lb + (1 - lb) * s) * b, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      inner: ImageFilter.blur(
        sigmaX: glass.backdropBlur,
        sigmaY: glass.backdropBlur,
      ),
    );
  }

  /// Заливка, отлив, кант и тени стекла — без размытия и обрезки.
  ///
  /// Отдельно от виджета, потому что стекло бывает и сливером
  /// (`GlassSliver`): ленивый список в коробку не обернуть, а облик у двух
  /// карточек рядом обязан быть один.
  static BoxDecoration decorationOf(
    BuildContext context, {
    required double radius,
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
        filter: filterOf(GlassSurfaceTheme.of(context)),
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
