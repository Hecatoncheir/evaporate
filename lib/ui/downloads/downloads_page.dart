import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/animated_progress.dart';
import '../../l10n/app_localizations.dart';

/// Загрузки: что качается сейчас и что пойдёт следом.
///
/// Очередь пользователь выстраивает сам — перетаскиванием игры из левого
/// списка и перестановкой элементов внутри очереди.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsBloc>().state;
    final library = context.watch<LibraryBloc>().state;
    final maxConcurrent = context.select<SettingsBloc, int>(
      (bloc) => bloc.state.maxConcurrent,
    );

    // Порядок задач в состоянии — это и есть порядок очереди.
    final active = downloads.tasks
        .where((t) => !t.isQueued && t.state != DownloadState.complete)
        .toList();
    final queued = downloads.tasks.where((t) => t.isQueued).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Row(
            children: [
              Text(
                L.of(context).downloads,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Text(
                L.of(context).concurrentAtOnce(maxConcurrent),
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (downloads.engine.state == EngineState.failed)
                OutlinedButton.icon(
                  onPressed: () => context.read<DownloadsBloc>().add(
                    const DownloadEngineRestartRequested(),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(L.of(context).restartEngine),
                ),
            ],
          ),
        ),
        if (downloads.engine.state == EngineState.failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _EngineFailure(message: downloads.engine.message),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: _AvailableGames(
                  library: library,
                  tasks: downloads.tasks,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _QueueColumn(
                  active: active,
                  queued: queued,
                  library: library,
                  allTasks: downloads.tasks,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Левая колонка: игры, которые можно поставить в очередь.
class _AvailableGames extends StatelessWidget {
  const _AvailableGames({required this.library, required this.tasks});

  final LibraryState library;
  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    final busyIds = tasks.map((t) => t.id).toSet();
    final available = library.games.where((game) {
      final source = game.source;
      if (source == null || source.kind == GameSourceKind.localFolder) {
        return false;
      }
      if (game.isInstalled) return false;
      final hash = game.infoHash;
      return hash == null || !busyIds.contains(hash);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            L.of(context).availableToDownload,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: available.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    L.of(context).allGamesQueued,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: available.length,
                  itemBuilder: (context, index) =>
                      _DraggableGame(game: available[index]),
                ),
        ),
      ],
    );
  }
}

class _DraggableGame extends StatelessWidget {
  const _DraggableGame({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final tile = _GameChip(game: game);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<Game>(
        data: game,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(width: 250, child: _GameChip(game: game)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        child: tile,
      ),
    );
  }
}

class _GameChip extends StatelessWidget {
  const _GameChip({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.drag_indicator,
            size: 16,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              game.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Правая колонка: активные загрузки и очередь, которую можно переставлять.
class _QueueColumn extends StatelessWidget {
  const _QueueColumn({
    required this.active,
    required this.queued,
    required this.library,
    required this.allTasks,
  });

  final List<DownloadTask> active;
  final List<DownloadTask> queued;
  final LibraryState library;
  final List<DownloadTask> allTasks;

  Game? _gameFor(DownloadTask task) {
    for (final game in library.games) {
      if (game.downloadTaskId == task.id || game.infoHash == task.id) {
        return game;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Game>(
      onAcceptWithDetails: (details) {
        final game = details.data;
        final source = game.source;
        if (source == null) return;
        // Новая задача встаёт в конец очереди — как в любом менеджере загрузок.
        context.read<DownloadsBloc>().add(
          DownloadRequested(game: game, source: source),
        );
      },
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: highlight
                ? context.colors.primary.withValues(alpha: 0.06)
                : null,
            border: Border.all(
              color: highlight ? context.colors.primary : Colors.transparent,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              _SectionTitle(
                L.of(context).nowDownloading,
                trailing: '${active.length}',
              ),
              if (active.isEmpty)
                _Hint(L.of(context).nothingDownloading)
              else
                for (final task in active)
                  _TaskCard(task: task, game: _gameFor(task)),
              const SizedBox(height: 18),
              _SectionTitle(
                L.of(context).nextInQueue,
                trailing: '${queued.length}',
              ),
              if (queued.isEmpty)
                _Hint(L.of(context).queueEmptyNote)
              else
                _QueueList(queued: queued, allTasks: allTasks, column: this),
            ],
          ),
        );
      },
    );
  }
}

/// Очередь с перестановкой перетаскиванием.
class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.queued,
    required this.allTasks,
    required this.column,
  });

  final List<DownloadTask> queued;
  final List<DownloadTask> allTasks;
  final _QueueColumn column;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: queued.length,
      // onReorderItem уже учитывает изъятие перемещаемого элемента,
      // поэтому индекс соседа ищем в списке без него.
      onReorderItem: (oldIndex, newIndex) {
        final moved = queued[oldIndex];
        final rest = [...queued]..removeAt(oldIndex);
        // Движку нужна позиция в общем порядке задач, а не внутри очереди:
        // сосед подсказывает, куда именно вставить.
        final target = newIndex < rest.length ? rest[newIndex] : null;
        final globalIndex = target == null
            ? allTasks.length - 1
            : allTasks.indexWhere((t) => t.id == target.id);
        if (globalIndex == -1) return;
        context.read<DownloadsBloc>().add(
          DownloadReordered(id: moved.id, newIndex: globalIndex),
        );
      },
      itemBuilder: (context, index) {
        final task = queued[index];
        return ReorderableDragStartListener(
          key: ValueKey(task.id),
          index: index,
          child: _QueuedCard(
            task: task,
            position: index + 1,
            game: column._gameFor(task),
          ),
        );
      },
    );
  }
}

class _QueuedCard extends StatelessWidget {
  const _QueuedCard({
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
              width: 22,
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                game?.title ?? task.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            Text(
              L.of(context).waitingInQueue,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            if (game != null)
              IconButton(
                onPressed: () => context.read<DownloadsBloc>().add(
                  DownloadCancelRequested(game!),
                ),
                icon: const Icon(Icons.close, size: 16),
                tooltip: L.of(context).removeFromQueue,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: context.colors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _EngineFailure extends StatelessWidget {
  const _EngineFailure({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.colors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? L.of(context).engineStopped,
              style: TextStyle(color: context.colors.danger, fontSize: 13),
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
            const SizedBox(height: 12),
            AnimatedProgress(
              value: indeterminate ? null : task.progress,
              height: 5,
              borderRadius: 4,
            ),
            const SizedBox(height: 10),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
              child: Row(
                children: [
                  Text(
                    task.isMetadata
                        ? L.of(context).fetchingMetadata
                        : '${formatBytes(task.completedBytes)} / '
                              '${formatBytes(task.totalBytes)}',
                  ),
                  const Spacer(),
                  if (task.downloadSpeed > 0) ...[
                    Text('↓ ${speedLabel(L.of(context), task.downloadSpeed)}'),
                    const SizedBox(width: 12),
                  ],
                  if (task.seeders > 0) ...[
                    Text(L.of(context).seedsCount(task.seeders)),
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 12),
                  ],
                  Text(L.of(context).peersCount(task.connections)),
                  if (!task.isMetadata && task.etaSeconds > 0) ...[
                    const SizedBox(width: 12),
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
