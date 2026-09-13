import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';
import 'download_activity.dart';

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
                    IconButton(
                      onPressed: () =>
                          downloads.add(DownloadResumeRequested(game!)),
                      icon: const Icon(Icons.play_arrow, size: 17),
                      tooltip: L.of(context).resume,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    IconButton(
                      onPressed: () =>
                          downloads.add(DownloadPauseRequested(game!)),
                      icon: const Icon(Icons.pause, size: 17),
                      tooltip: L.of(context).pause,
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    onPressed: () =>
                        downloads.add(DownloadCancelRequested(game!)),
                    icon: const Icon(Icons.close, size: 17),
                    tooltip: L.of(context).cancelDownload,
                    visualDensity: VisualDensity.compact,
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
