import 'package:flutter/material.dart';

import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../downloads/download_chart.dart';
import '../../theme.dart';
import 'detail_header.dart';

/// Заголовок качающейся игры поверх её же графика загрузки.
///
/// Обложка, название и описание ложатся на живую подложку: страница
/// отвечает на «как идёт вот эта игра» одним взглядом, не отправляя за
/// ответом ни на соседний экран, ни даже ниже по странице.
///
/// График здесь — фон, а не показание. Точные числа стоят ниже, у клавиш,
/// и оттуда их читают; отсюда и приглушение, и прижатие книзу: полный
/// накал во всю высоту спорил бы с названием, которое и есть главное на
/// странице.
///
/// Высоту задаёт заголовок, а не график: [Positioned.fill] растягивает
/// подложку по тому, что вышло у текста. Иначе короткое описание оставляло
/// бы под собой пустую полосу, а длинное — обрезало бы график.
class DownloadingHeader extends StatelessWidget {
  const DownloadingHeader({super.key, required this.game, required this.task});

  final Game game;
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
            child: Opacity(
              opacity: EvaporateAlpha.underlay,
              // Без своей высоты: заполняет то, что вышло у заголовка.
              // Прижатый книзу график не доставал бы до названия, а оно и
              // есть то, подо что подложку кладут.
              child: DownloadChart(task: task, height: null),
            ),
          ),
        ),
        DetailHeader(game: game, task: task),
      ],
    );
  }
}
