import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../services/download/download_engine.dart';
import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsBloc>().state;
    final library = context.watch<LibraryBloc>().state;
    final status = downloads.engine;
    final tasks = downloads.tasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Row(
            children: [
              const Text(
                'Загрузки',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (status.state == EngineState.failed ||
                  status.state == EngineState.missingBinary)
                OutlinedButton.icon(
                  onPressed: () => context.read<DownloadsBloc>().add(
                    const DownloadEngineStartRequested(),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Повторить запуск'),
                ),
            ],
          ),
        ),
        if (!status.isReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _EngineNotice(status: status),
          ),
        Expanded(
          child: tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.download_outlined,
                  title: 'Активных загрузок нет',
                  description:
                      'Добавьте игру в библиотеке — magnet-ссылкой '
                      'или .torrent-файлом — и она появится здесь.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskCard(
                      task: task,
                      game: _findGame(library, task),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static Game? _findGame(LibraryState library, DownloadTask task) {
    for (final game in library.games) {
      if (game.downloadGid == task.id) return game;
    }
    return null;
  }
}

/// Объясняет, что делать, если движок недоступен: без aria2c приложение
/// остаётся рабочим, но качать не может.
class _EngineNotice extends StatelessWidget {
  const _EngineNotice({required this.status});

  final EngineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.state == EngineState.failed
        ? EvaporateTheme.danger
        : EvaporateTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.message ?? status.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.game});

  final DownloadTask task;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsBloc>();
    final indeterminate = task.isMetadata || task.totalBytes == 0;

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
                Text(
                  task.stateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: task.state == DownloadState.error
                        ? EvaporateTheme.danger
                        : EvaporateTheme.textSecondary,
                  ),
                ),
                if (game != null) ...[
                  const SizedBox(width: 8),
                  if (task.state == DownloadState.active)
                    IconButton(
                      onPressed: () =>
                          downloads.add(DownloadPauseRequested(game!)),
                      icon: const Icon(Icons.pause, size: 17),
                      tooltip: 'Пауза',
                      visualDensity: VisualDensity.compact,
                    )
                  else if (task.state == DownloadState.paused)
                    IconButton(
                      onPressed: () =>
                          downloads.add(DownloadResumeRequested(game!)),
                      icon: const Icon(Icons.play_arrow, size: 17),
                      tooltip: 'Продолжить',
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    onPressed: () =>
                        downloads.add(DownloadCancelRequested(game!)),
                    icon: const Icon(Icons.close, size: 17),
                    tooltip: 'Отменить',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: indeterminate ? null : task.progress,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 10),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 12,
                color: EvaporateTheme.textSecondary,
              ),
              child: Row(
                children: [
                  Text(
                    task.isMetadata
                        ? 'Получаем метаданные…'
                        : '${formatBytes(task.completedBytes)} / '
                              '${formatBytes(task.totalBytes)}',
                  ),
                  const Spacer(),
                  if (task.downloadSpeed > 0) ...[
                    Text('↓ ${formatSpeed(task.downloadSpeed)}'),
                    const SizedBox(width: 12),
                  ],
                  if (task.uploadSpeed > 0) ...[
                    Text('↑ ${formatSpeed(task.uploadSpeed)}'),
                    const SizedBox(width: 12),
                  ],
                  if (task.seeders > 0) ...[
                    Text('сидов: ${task.seeders}'),
                    const SizedBox(width: 12),
                  ],
                  Text('пиров: ${task.connections}'),
                  if (!task.isMetadata && task.etaSeconds > 0) ...[
                    const SizedBox(width: 12),
                    Text('осталось ${formatEta(task.etaSeconds)}'),
                  ],
                ],
              ),
            ),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                task.errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: EvaporateTheme.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
