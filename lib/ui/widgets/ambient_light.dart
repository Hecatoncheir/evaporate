import 'package:flutter/material.dart';

import '../theme.dart';

/// Свет выбранной игры, заливающий корпус приложения.
///
/// Это главный источник цвета в оболочке: сам корпус нарочно сдержан —
/// чернила и золото, — а красочность приносят игры. Библиотека каждого
/// человека светится по-своему, и при перелистывании свет перетекает, а не
/// переключается: длинный переход и есть то, из-за чего оболочка кажется
/// собранной, а не перекрашенной.
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
    final motion = context.motion;

    // Без выбранной игры корпус греется своим цветом, а не гаснет: пустая
    // библиотека не должна выглядеть выключенным прибором.
    final tints = title == null
        ? [colors.primary, colors.accent, colors.surfaceHigh]
        : gameAmbientColors(title!);

    // Светлый корпус берёт свет вполсилы: на белом та же заливка читается
    // как грязь на панели, а не как подсветка.
    final strength = HardwareSurfaceTheme.of(context).ambientStrength;

    Widget wash(Alignment center, double radius, Color tint, double alpha) =>
        AnimatedContainer(
          duration: motion.slow,
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

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (enabled) ...[
            wash(const Alignment(-0.75, -0.95), 1.05, tints[0], 0.38),
            wash(const Alignment(0.85, -0.8), 0.95, tints[1], 0.32),
            wash(const Alignment(0.1, 1.15), 1.2, tints[2], 0.42),
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
