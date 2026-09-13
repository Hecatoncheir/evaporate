import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';
import 'cancel_dialog.dart';
import 'download_activity.dart';

/// Отмена спрашивает, как и на странице игры.
///
/// Задача снимается насовсем: место в очереди, обмен с пирами и состояние
/// кусков теряются, а игра уходит из «качается» обратно в «не
/// установлена». Файлы при этом остаются, но продолжить с того же места
/// одним нажатием уже нельзя.
Future<void> _cancel(BuildContext context, Game game, DownloadTask task) async {
  final downloads = context.read<DownloadsBloc>();
  final choice = await askCancel(
    context,
    title: L.of(context).cancelDownloadQuestion,
    message: L.of(context).cancelDownloadNote,
    // «Удалить», а не «Отменить»: рядом стоит «Удалить совсем вместе с
    // файлами», и два ответа должны читаться парой, от меньшего к
    // большему. Подсказка на самой клавише остаётся «Отменить» — там, в
    // ряду с паузой, это точное слово.
    confirmLabel: L.of(context).cancelDownloadConfirm,
    confirmIcon: Icons.remove_circle_outline,
    task: task,
  );
  if (choice == null) return;
  downloads.add(
    DownloadCancelRequested(
      game,
      deleteFiles: choice == CancelChoice.withFiles,
    ),
  );
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.game});

  final DownloadTask task;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsBloc>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    game?.title ?? task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Названия релизов длинные и обрезаются по месту: без
                // просвета многоточие упиралось бы прямо в состояние.
                const SizedBox(width: 12),
                Text(
                  task.isMetadata
                      ? L.of(context).stateMetadata
                      : downloadStateLabel(L.of(context), task.state),
                  style: TextStyle(
                    fontSize: 12,
                    color: task.state == DownloadState.error
                        ? context.colors.danger
                        : context.colors.textSecondary,
                  ),
                ),
                if (game != null) ...[
                  const SizedBox(width: 8),
                  if (task.state == DownloadState.paused)
                    IconAction(
                      onPressed: () =>
                          downloads.add(DownloadResumeRequested(game!)),
                      icon: Icons.play_arrow,
                      tooltip: L.of(context).resume,
                    )
                  else
                    IconAction(
                      onPressed: () =>
                          downloads.add(DownloadPauseRequested(game!)),
                      icon: Icons.pause,
                      tooltip: L.of(context).pause,
                    ),
                  const SizedBox(width: 6),
                  IconAction(
                    onPressed: () => _cancel(context, game!, task),
                    icon: Icons.close,
                    tooltip: L.of(context).cancelDownload,
                    danger: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            DownloadActivity(key: ValueKey(task.id), task: task),
            const SizedBox(height: 12),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (task.seeders > 0) ...[
                    Text(L.of(context).seedsCount(task.seeders)),
                  ],
                  // Отданное показываем всегда, когда оно есть: раздача —
                  // плата за скачанное, и знать свой вклад пользователь вправе.
                  if (task.uploadedBytes > 0) ...[
                    Text(
                      L
                          .of(context)
                          .uploadedTotal(formatBytes(task.uploadedBytes)),
                    ),
                    if (task.completedBytes > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        L
                            .of(context)
                            .ratioValue(
                              (task.uploadedBytes / task.completedBytes)
                                  .toStringAsFixed(2),
                            ),
                      ),
                    ],
                  ],
                  Text(L.of(context).peersCount(task.connections)),
                  if (!task.isMetadata && task.etaSeconds > 0) ...[
                    Text(
                      L
                          .of(context)
                          .etaLeft(
                            formatEtaLabel(L.of(context), task.etaSeconds),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                task.errorMessage!,
                style: TextStyle(fontSize: 12, color: context.colors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
