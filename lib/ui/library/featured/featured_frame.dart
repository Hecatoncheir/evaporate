import 'package:flutter/material.dart';

import '../../theme.dart';

/// Корпус крупного кадра: волосяной золотой кант, тень и скруглённый вырез.
///
/// Кант отделяет кадр от корпуса приложения, не споря с самой картинкой, а
/// тень своя у каждой схемы: ночью мягкая, днём короткая и жёсткая.
class FeaturedFrame extends StatelessWidget {
  const FeaturedFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = HardwareSurfaceTheme.of(context);
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.primary.withValues(alpha: EvaporateAlpha.soft),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: surface.frameShadowBlur,
            offset: Offset(0, surface.frameShadowDrop),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}
