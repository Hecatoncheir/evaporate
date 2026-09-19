import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cancel_dialog.dart';
import 'task_card.dart';

/// Спрашиваем и здесь: клавиша та же и делает то же самое, а очередь — не
/// черновик, человек её выстраивал. Текст, однако, свой: тут ничего не
/// качается прямо сейчас, и обещать «задача будет снята» посреди загрузки
/// было бы не про то.
Future<void> _removeFromQueue(
  BuildContext context,
  Game game,
  DownloadTask task,
) async {
  final downloads = context.read<DownloadsBloc>();
  final choice = await askCancel(
    context,
    title: L.of(context).removeFromQueueQuestion,
    message: L.of(context).removeFromQueueNote,
    confirmLabel: L.of(context).removeFromQueue,
    confirmIcon: Icons.playlist_remove_rounded,
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
              style: context.text.captionMuted,
            ),
            if (game != null)
              // Та же клавиша, что на карточке задачи: действие одно и то
              // же, и выглядеть на одном экране по-разному ему незачем.
              IconAction(
                onPressed: () => _removeFromQueue(context, game!, task),
                icon: Icons.close,
                tooltip: L.of(context).removeFromQueue,
                danger: true,
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
          Text(text.toUpperCase(), style: context.text.label),
          if (trailing != null) ...[
            const SizedBox(width: 9),
            Text(
              trailing!,
              style: context.text.label.copyWith(color: context.colors.primary),
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
      child: Text(text, style: context.text.paragraph),
    );
  }
}
