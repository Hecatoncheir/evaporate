import 'package:flutter/material.dart';

import '../theme.dart';

/// Свет выбранной игры, заливающий корпус приложения.
///
/// Это главный источник цвета в оболочке: сам корпус нарочно сдержан —
/// чернила и огонь главного действия, — а красочность приносят игры.
/// Библиотека каждого человека светится по-своему, и при перелистывании
/// свет перетекает, а не переключается: длинный переход и есть то, из-за
/// чего оболочка кажется собранной, а не перекрашенной.
///
/// Рисуется тремя большими радиальными переходами без размытия. Размывать
/// нечего: переход и так мягкий, а `BackdropFilter` на всё окно стоил бы
/// кадров на каждой перерисовке.
class AmbientLight extends StatelessWidget {
  const AmbientLight({
    super.key,
    required this.enabled,
    required this.title,
    required this.child,
  });

  /// Настройка «окружение». Выключено — остаются фон и виньетка: рамка
  /// кадра к украшениям не относится.
  final bool enabled;

  /// Название выбранной игры. От него берётся цвет — см. [gameAmbientColors].
  final String? title;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Без выбранной игры корпус греется своим цветом, а не гаснет: пустая
    // библиотека не должна выглядеть выключенным прибором.
    final tints = title == null
        ? [colors.primary, colors.accent, colors.surfaceHigh]
        : gameAmbientColors(title!);

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (enabled) ...[
            _AmbientWash(
              center: const Alignment(-0.75, -0.95),
              radius: 1.05,
              tint: tints[0],
              alpha: 0.38,
            ),
            _AmbientWash(
              center: const Alignment(0.85, -0.8),
              radius: 0.95,
              tint: tints[1],
              alpha: 0.32,
            ),
            _AmbientWash(
              center: const Alignment(0.1, 1.15),
              radius: 1.2,
              tint: tints[2],
              alpha: 0.42,
            ),
          ],
          // Виньетка собирает кадр и не даёт свету вытечь за края окна.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1,
                colors: [
                  AppColors.transparent,
                  colors.shadow.withValues(
                    alpha: HardwareSurfaceTheme.of(context).vignetteOpacity,
                  ),
                ],
                stops: const [0.5, 1],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Одно пятно света игры: радиальный переход от оттенка к прозрачному.
///
/// Сила берётся из материала корпуса: светлый корпус держит свет вполсилы,
/// на белом та же заливка читалась бы как грязь на панели. Смена оттенка
/// при перелистывании перетекает, а не щёлкает.
class _AmbientWash extends StatelessWidget {
  const _AmbientWash({
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
