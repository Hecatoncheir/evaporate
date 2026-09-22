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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = HardwareSurfaceTheme.of(context);
    final glass = GlassSurfaceTheme.of(context);
    final effectiveOpacity = opacity ?? glass.fillOpacity;
    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
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
            borderRadius: borderRadius,
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
