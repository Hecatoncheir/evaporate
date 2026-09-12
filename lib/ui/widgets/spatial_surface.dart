import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Мягкий свет за основными панелями. Он даёт стеклу глубину даже на
/// страницах без обложек и не перехватывает ввод.
class SpatialBackdrop extends StatelessWidget {
  const SpatialBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.background,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ambientBlue.withValues(alpha: dark ? 0.28 : 0.18),
            context.colors.background,
            AppColors.ambientViolet.withValues(alpha: dark ? 0.22 : 0.12),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -180,
            top: -220,
            width: 520,
            height: 520,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.ambientMint.withValues(alpha: dark ? 0.18 : 0.12),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Унифицированная visionOS-подобная поверхность: полупрозрачная заливка,
/// тонкий световой кант и blur содержимого позади неё.
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
    final effectiveOpacity = opacity ?? (colors.isDark ? 0.72 : 0.78);
    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: effectiveOpacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: colors.textPrimary.withValues(
                alpha: colors.isDark ? 0.14 : 0.26,
              ),
            ),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: colors.background.withValues(alpha: 0.34),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
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
