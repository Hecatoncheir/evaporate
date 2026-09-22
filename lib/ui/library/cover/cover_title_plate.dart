import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';

/// Название на подложке — когда обложки нет.
///
/// Цвет выводится из названия, а не берётся из палитры: соседние плитки
/// должны отличаться друг от друга, иначе библиотека без картинок выглядит
/// стеной одинаковых прямоугольников. Оттенок у игры всегда один и тот же.
///
/// Тёмная в обеих темах, как и настоящие обложки: подложка заменяет
/// картинку, а не продолжает фон приложения, и белое название по ней должно
/// читаться при любых настройках.
class CoverTitlePlate extends StatelessWidget {
  const CoverTitlePlate({
    super.key,
    required this.game,
    required this.underStrip,
  });

  final Game game;
  final bool underStrip;

  /// Поле снизу, когда поверх обложки идёт полоса хода загрузки: высота
  /// полосы и воздух над ней. Это размер соседа, а не ступень шкалы.
  static const _aboveStrip = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gameCoverColors(game.title),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        EvaporateSpacing.field,
        EvaporateSpacing.field,
        EvaporateSpacing.field,
        underStrip ? _aboveStrip : EvaporateSpacing.field,
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        game.title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          // Подложка своя и в обеих темах тёмная — белый по ней читается,
          // а цвет из палитры на ней бы терялся.
          color: AppColors.coverText,
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 6, color: AppColors.coverTextShadow)],
        ),
      ),
    );
  }
}
