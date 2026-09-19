import 'package:flutter/material.dart';

import '../theme.dart';

/// Одно пятно света игры: радиальный переход от оттенка к прозрачному.
///
/// Сила берётся из материала корпуса: светлый корпус держит свет вполсилы,
/// на белом та же заливка читалась бы как грязь на панели. Смена оттенка
/// при перелистывании перетекает, а не щёлкает.
class AmbientWash extends StatelessWidget {
  const AmbientWash({
    super.key,
    required this.center,
    required this.radius,
    required this.tint,
    required this.alpha,
  });

  final Alignment center;
  final double radius;
  final Color tint;

  /// Плотность в центре пятна до поправки на материал.
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final strength = HardwareSurfaceTheme.of(context).ambientStrength;
    return AnimatedContainer(
      duration: context.motion.slow,
      curve: EvaporateMotion.ease,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            tint.withValues(alpha: alpha * strength),
            AppColors.transparent,
          ],
        ),
      ),
    );
  }
}
