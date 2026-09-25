import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'decorative_motion.dart';

/// Полоса загрузки, которая едет к новому значению, а не прыгает.
///
/// Движок сообщает о ходе загрузки раз в секунду, и без сглаживания полоса
/// дёргается ступенями. Заодно это честнее выглядит: загрузка идёт непрерывно,
/// а не рывками, как показывал прежний вариант.
///
/// Пока задача в работе, по заполненной части идут наклонные полосы. Они не
/// украшение: заполнение на восьмидесяти процентах и **замершее** на
/// восьмидесяти выглядят одинаково, и без них непонятно, работает ли
/// загрузка вообще.
class AnimatedProgress extends StatelessWidget {
  const AnimatedProgress({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.track,
    this.borderRadius = EvaporateTheme.radiusChip,
    this.busy = false,
  });

  /// Доля от нуля до единицы. `null` — неизвестно, полоса бежит сама.
  final double? value;
  final double height;
  final Color? color;

  /// Дорожка под заполнением. Поверх обложки она своя: подложка там —
  /// картинка, а не корпус, и цвет корпуса на светлой схеме выбелил бы её.
  final Color? track;

  final double borderRadius;

  /// Задача идёт прямо сейчас — по полосе бегут насечки.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = color ?? colors.primaryFill;
    final under = track ?? colors.surfaceHigh;

    // Неопределённому прогрессу сглаживать нечего: там своя анимация.
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: under,
          valueColor: AlwaysStoppedAnimation(line),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: under),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value!.clamp(0.0, 1.0)),
              duration: context.motion.track,
              curve: EvaporateMotion.ease,
              builder: (context, animated, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: animated,
                  // Высоту тянем на всю: без неё `DecoratedBox` без ребёнка
                  // схлопывается в ноль — заливки не видно вовсе, а видна
                  // одна пустая дорожка. Ровно так полоса и выглядела с тех
                  // пор, как её собрали из градиента вместо готового
                  // индикатора: в дереве заполнение честные 34%, а на
                  // экране — ничего.
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Переход от служебного цвета к фирменному: у полосы
                      // появляется направление, и видно, куда она едет.
                      gradient: LinearGradient(
                        colors: [colors.accentFill, line],
                      ),
                    ),
                    child: busy ? const _ProgressHatching() : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Наклонные насечки, бегущие по заполненной части.
class _ProgressHatching extends StatelessWidget {
  const _ProgressHatching();

  @override
  Widget build(BuildContext context) => DecorativeMotion(
    enabled: true,
    builder: (context, clock, _) => CustomPaint(
      painter: _HatchPainter(clock: clock, color: AppColors.artSweep),
    ),
  );
}

class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.clock, required this.color})
    : super(repaint: clock);

  final ValueListenable<double> clock;
  final Color color;

  /// Шаг насечек и скорость их бега.
  static const _step = 14.0;
  static const _speed = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shift = (clock.value * _speed) % _step;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    for (var x = -size.height - _step; x < size.width + _step; x += _step) {
      final at = x - shift;
      canvas.drawLine(
        Offset(at + size.height, 0),
        Offset(at, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.clock != clock;
}
