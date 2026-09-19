import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../widgets/icon_action.dart';
import 'cancel_dialog.dart';

/// Пауза (она же продолжение) и отмена на карточке задачи.
class TaskActions extends StatelessWidget {
  const TaskActions({super.key, required this.task, required this.game});

  final DownloadTask task;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final downloads = context.read<DownloadsBloc>();
    final paused = task.state == DownloadState.paused;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconAction(
          onPressed: () => downloads.add(
            paused
                ? DownloadResumeRequested(game)
                : DownloadPauseRequested(game),
          ),
          icon: paused ? Icons.play_arrow : Icons.pause,
          tooltip: paused ? l.resume : l.pause,
        ),
        const SizedBox(width: 6),
        IconAction(
          onPressed: () => _cancel(context),
          icon: Icons.close,
          tooltip: l.cancelDownload,
          danger: true,
        ),
      ],
    );
  }

  /// Отмена спрашивает, как и на странице игры.
  ///
  /// Задача снимается насовсем: место в очереди, обмен с пирами и
  /// состояние кусков теряются, а игра уходит из «качается» обратно в «не
  /// установлена». Файлы при этом остаются, но продолжить с того же места
  /// одним нажатием уже нельзя.
  Future<void> _cancel(BuildContext context) {
    final l = L.of(context);
    return cancelDownload(
      context,
      game: game,
      task: task,
      title: l.cancelDownloadQuestion,
      message: l.cancelDownloadNote,
      // «Удалить», а не «Отменить»: рядом стоит «Удалить совсем вместе с
      // файлами», и два ответа должны читаться парой, от меньшего к
      // большему. Подсказка на самой клавише остаётся «Отменить» — там, в
      // ряду с паузой, это точное слово.
      confirmLabel: l.cancelDownloadConfirm,
      confirmIcon: Icons.remove_circle_outline,
    );
  }
}
