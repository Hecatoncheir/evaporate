import 'package:flutter/material.dart';

import '../theme.dart';

/// Полоса загрузки, которая едет к новому значению, а не прыгает.
///
/// Движок сообщает о ходе загрузки раз в секунду, и без сглаживания полоса
/// дёргается ступенями. Заодно это честнее выглядит: загрузка идёт непрерывно,
/// а не рывками, как показывал прежний вариант.
class AnimatedProgress extends StatelessWidget {
  const AnimatedProgress({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.borderRadius = 3,
  });

  /// Доля от нуля до единицы. `null` — неизвестно, полоса бежит сама.
  final double? value;
  final double height;
  final Color? color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final line = color ?? context.colors.primary;

    // Неопределённому прогрессу сглаживать нечего: там своя анимация.
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: context.colors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(line),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value!.clamp(0.0, 1.0)),
      // Чуть дольше, чем приходят сообщения о ходе загрузки: полоса едет
      // непрерывно, не успевая замереть между ними.
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, animated, _) => ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: context.colors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(line),
        ),
      ),
    );
  }
}
