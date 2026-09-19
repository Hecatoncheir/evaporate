import 'package:flutter/material.dart';

import '../theme.dart';
import 'progress_hatching.dart';

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
    this.borderRadius = 3,
    this.busy = false,
  });

  /// Доля от нуля до единицы. `null` — неизвестно, полоса бежит сама.
  final double? value;
  final double height;
  final Color? color;
  final double borderRadius;

  /// Задача идёт прямо сейчас — по полосе бегут насечки.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = color ?? colors.primaryFill;

    // Неопределённому прогрессу сглаживать нечего: там своя анимация.
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: colors.surfaceHigh,
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
            ColoredBox(color: colors.surfaceHigh),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value!.clamp(0.0, 1.0)),
              // Чуть дольше, чем приходят сообщения о ходе загрузки: полоса
              // едет непрерывно, не успевая замереть между ними.
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
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
                    child: busy ? const ProgressHatching() : null,
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
