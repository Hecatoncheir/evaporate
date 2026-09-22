import 'package:flutter/material.dart';

import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../downloads/download_activity.dart';
import '../primary_action.dart';
import 'download_summary.dart';
import 'game_error_note.dart';
import 'primary_actions.dart';
import 'steam_actions.dart';

/// Главная кнопка карточки плюс прогресс загрузки.
///
/// Занятость приходит из состояния блока: виджету больше не нужен свой
/// флаг и `try/catch` — ошибки показывает общий слушатель в оболочке.
class ActionPanel extends StatelessWidget {
  const ActionPanel({super.key, required this.game, required this.task});

  final Game game;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context) {
    final primary = PrimaryActions(game: game, task: task);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Слева — то, что делают с самой игрой, справа — с её ярлыком
            // в Steam. Правая половина забирает всё оставшееся место и
            // прижимает клавиши к краю. Распорка тут не годится, хотя
            // напрашивается: она делила бы свободное место с ними поровну,
            // и подписи переносились бы на вторую строку при живом пустом
            // месте слева.
            Row(
              children: [
                // Гибкой левая половина бывает только с пояснением рядом с
                // «Играть»: оно должно переноситься, а не выталкивать Steam.
                // Без пояснения гибкость отняла бы у правой половины её
                // долю места, и клавиши Steam ушли бы на вторую строку.
                if (primaryActionFor(game) == PrimaryAction.play &&
                    !game.canLaunch)
                  Flexible(child: primary)
                else
                  primary,
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SteamActions(game: game),
                  ),
                ),
              ],
            ),
            if (task != null && !task!.isFinished) ...[
              const SizedBox(height: 16),
              // Без графика: он уехал подложкой под заголовок страницы, и
              // рисовать его здесь второй раз незачем. История у них общая
              // — `DownloadHistoryBloc` один на приложение.
              DownloadActivity(task: task!, showChart: false),
              const SizedBox(height: 10),
              DownloadSummary(task: task!),
            ],
            if (game.status == GameStatus.error && game.lastError != null) ...[
              const SizedBox(height: 14),
              GameErrorNote(message: game.lastError!),
            ],
          ],
        ),
      ),
    );
  }
}
