import 'dart:io';

import 'package:flutter/material.dart';

import 'shots_timing.dart';

/// Один кадр: сдвинут по горизонтали и увеличен ровно настолько, чтобы
/// сдвиг не открыл край.
class ShotFrame extends StatelessWidget {
  const ShotFrame({
    super.key,
    required this.path,
    required this.offset,
    required this.opacity,
    required this.fallback,
  });

  final String path;

  /// Доля черёда, пройденная кадром: 0 — начало своего черёда, 1 — уход.
  /// Отрицательное значение — разбег до собственного черёда.
  final double offset;
  final double opacity;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    // Середина пути, а не половина черёда: путь начинается с разбега, и
    // отсчёт от 0.5 увёл бы кадр в одну сторону сильнее, чем в другую.
    const middle = (1 - ShotsTiming.preroll) / 2;
    final shift = (offset - middle) * ShotsTiming.drift;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        // Масштаб под весь размах сдвига и ещё десятая часть сверху: без
        // запаса край кадра приходится ровно на границу, и округление в
        // крайних положениях обнажает у рамки полоску фона.
        scale: 1 + ShotsTiming.drift * ShotsTiming.span * 1.1,
        // Доля собственной ширины, а не ширины окна: подложка занимает
        // крупный кадр библиотеки, а не экран, и от `MediaQuery` дрейф
        // менялся бы с размером окна при неизменном кадре.
        child: FractionalTranslation(
          translation: Offset(shift, 0),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        ),
      ),
    );
  }
}
