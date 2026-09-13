import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';
import 'task_card.dart';

/// Правая колонка: активные загрузки и очередь, которую можно переставлять.
class QueueColumn extends StatelessWidget {
  const QueueColumn({
    super.key,
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
              color: highlight ? context.colors.primary : AppColors.transparent,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              SectionTitle(
                L.of(context).nowDownloading,
                trailing: '${active.length}',
              ),
              if (active.isEmpty)
                QueueHint(L.of(context).nothingDownloading)
              else
                for (final task in active)
                  TaskCard(task: task, game: _gameFor(task)),
              const SizedBox(height: 18),
              SectionTitle(
                L.of(context).nextInQueue,
                trailing: '${queued.length}',
              ),
              if (queued.isEmpty)
                QueueHint(L.of(context).queueEmptyNote)
              else
                QueueList(queued: queued, allTasks: allTasks, column: this),
            ],
          ),
        );
      },
    );
  }
}

/// Очередь с перестановкой перетаскиванием.
class QueueList extends StatelessWidget {
  const QueueList({
    super.key,
    required this.queued,
    required this.allTasks,
    required this.column,
  });

  final List<DownloadTask> queued;
  final List<DownloadTask> allTasks;
  final QueueColumn column;

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
          child: QueuedCard(
            task: task,
            position: index + 1,
            game: column._gameFor(task),
          ),
        );
      },
    );
  }
}

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
                style: TextStyle(
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Подпись на корпусе, а не заголовок абзаца: моноширинная, заглавными,
    // а число рядом — фирменным цветом, чтобы читалось как показание.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: context.colors.textSecondary,
              fontFamily: EvaporateTheme.monoFontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 9),
            Text(
              trailing!,
              style: TextStyle(
                color: context.colors.primary,
                fontFamily: EvaporateTheme.monoFontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QueueHint extends StatelessWidget {
  const QueueHint(this.text, {super.key});

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
