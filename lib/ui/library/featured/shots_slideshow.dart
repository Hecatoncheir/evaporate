import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../featured/shot_frame.dart';
import 'shots_timing.dart';

class ShotsSlideshow extends StatelessWidget {
  const ShotsSlideshow({
    super.key,
    required this.shots,
    required this.clock,
    required this.fallback,
  });

  final List<String> shots;
  final ValueListenable<double> clock;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, time, _) {
        const period = ShotsTiming.hold + ShotsTiming.fade;
        final turn = time / period;
        final index = turn.floor();
        final phase = turn - index;

        // Перетекание занимает хвост черёда, поэтому следующий кадр нужен
        // только под конец: остальное время он не рисуется вовсе.
        final blend = phase <= ShotsTiming.hold / period
            ? 0.0
            : Curves.easeInOut.transform(
                (phase - ShotsTiming.hold / period) /
                    (ShotsTiming.fade / period),
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            ShotFrame(
              path: shots[index % shots.length],
              // Кадр отъезжает за свой черёд целиком, а не за одно
              // перетекание: иначе движение шло бы рывками — стоял,
              // дёрнулся, стоял.
              offset: phase,
              opacity: 1,
              fallback: fallback,
            ),
            if (blend > 0)
              ShotFrame(
                path: shots[(index + 1) % shots.length],
                // Отрицательное смещение — тот самый разбег: к началу
                // своего черёда кадр придёт ровно к нулю и продолжит путь
                // без стыка.
                offset: phase - 1,
                opacity: blend,
                fallback: fallback,
              ),
          ],
        );
      },
    ),
  );
}
