import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Мягкий свет за основными панелями. Он собирает окно в единый аппаратный
/// корпус даже на страницах без обложек и не перехватывает ввод.
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
            AppColors.ambientSteel.withValues(alpha: dark ? 0.14 : 0.32),
            context.colors.background,
            AppColors.ambientCharcoal.withValues(alpha: dark ? 0.36 : 0.12),
          ],
          stops: const [0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -170,
            top: -240,
            width: 560,
            height: 560,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.ambientOrange.withValues(
                      alpha: dark ? 0.16 : 0.12,
                    ),
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
    final effectiveOpacity = opacity ?? (colors.isDark ? 0.9 : 0.94);
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
                  alpha: colors.isDark ? effectiveOpacity : 0.98,
                ),
                colors.surfaceHigh.withValues(
                  alpha: colors.isDark ? 0.62 : 0.72,
                ),
              ],
            ),
            borderRadius: borderRadius,
            border: Border.all(
              color: colors.textPrimary.withValues(
                alpha: colors.isDark ? 0.15 : 0.32,
              ),
            ),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: colors.isDark
                          ? AppColors.hardwareShadowDark
                          : AppColors.hardwareShadowLight,
                      blurRadius: 24,
                      offset: const Offset(10, 14),
                    ),
                    BoxShadow(
                      color: colors.textPrimary.withValues(
                        alpha: colors.isDark ? 0.05 : 0.16,
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

/// Перфорированная решётка — короткая визуальная подпись аппаратного стиля.
/// Она декоративна, поэтому не попадает в дерево доступности.
class HardwareGrille extends StatelessWidget {
  const HardwareGrille({super.key, this.width = 88, this.height = 46});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _GrillePainter(
          plate: context.colors.surfaceHigh,
          hole: context.colors.isDark
              ? AppColors.grilleHoleDark
              : AppColors.grilleHoleLight,
          light: context.colors.primary,
        ),
      ),
    ),
  );
}

class _GrillePainter extends CustomPainter {
  const _GrillePainter({
    required this.plate,
    required this.hole,
    required this.light,
  });

  final Color plate;
  final Color hole;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = plate,
    );
    const gap = 8.0;
    final rows = (size.height / gap).floor();
    final columns = (size.width / gap).floor();
    final xInset = (size.width - (columns - 1) * gap) / 2;
    final yInset = (size.height - (rows - 1) * gap) / 2;
    final holePaint = Paint()..color = hole;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        canvas.drawCircle(
          Offset(xInset + column * gap, yInset + row * gap),
          2.05,
          holePaint,
        );
      }
    }
    canvas.drawCircle(
      Offset(size.width - 8, 8),
      3.2,
      Paint()
        ..color = light
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GrillePainter oldDelegate) =>
      oldDelegate.plate != plate ||
      oldDelegate.hole != hole ||
      oldDelegate.light != light;
}
