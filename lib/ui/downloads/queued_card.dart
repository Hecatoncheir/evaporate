import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/icon_action.dart';
import 'cancel_dialog.dart';

/// Задача, ждущая в очереди: место, название и снятие из очереди.
class QueuedCard extends StatelessWidget {
  const QueuedCard({
    super.key,
    required this.task,
    required this.position,
    required this.game,
  });

  final DownloadTask task;
  final int position;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 17,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 24,
              child: Text(
                '$position',
                style: context.text.figure.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                game?.title ?? task.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.body,
              ),
            ),
            Text(
              L.of(context).waitingInQueue,
              style: context.text.captionMuted,
            ),
            if (game != null)
              // Та же клавиша, что на карточке задачи: действие одно и то
              // же, и выглядеть на одном экране по-разному ему незачем.
              IconAction(
                onPressed: () => _remove(context, game!),
                icon: Icons.close,
                tooltip: L.of(context).removeFromQueue,
                danger: true,
              ),
          ],
        ),
      ),
    );
  }

  /// Спрашиваем и здесь: клавиша та же и делает то же самое, а очередь — не
  /// черновик, человек её выстраивал. Текст, однако, свой: тут ничего не
  /// качается прямо сейчас, и обещать «задача будет снята» посреди загрузки
  /// было бы не про то.
  Future<void> _remove(BuildContext context, Game game) {
    final l = L.of(context);
    return cancelDownload(
      context,
      game: game,
      task: task,
      title: l.removeFromQueueQuestion,
      message: l.removeFromQueueNote,
      confirmLabel: l.removeFromQueue,
      confirmIcon: Icons.playlist_remove_rounded,
    );
  }
}
