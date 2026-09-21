import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'queue_hint.dart';
import 'queue_list.dart';
import 'section_title.dart';
import 'task_card.dart';

/// Правая колонка: активные загрузки и очередь, которую можно переставлять.
class QueueColumn extends StatelessWidget {
  const QueueColumn({
    super.key,
    required this.active,
    required this.queued,
    required this.library,
  });

  final List<DownloadTask> active;
  final List<DownloadTask> queued;
  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Game>(
      onAcceptWithDetails: (details) {
        final game = details.data;
        final source = game.download.source;
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
                ? context.colors.primary.withValues(
                    alpha: EvaporateAlpha.subtle,
                  )
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
                  TaskCard(task: task, game: library.gameForTask(task.id)),
              const SizedBox(height: 18),
              SectionTitle(
                L.of(context).nextInQueue,
                trailing: '${queued.length}',
              ),
              if (queued.isEmpty)
                QueueHint(L.of(context).queueEmptyNote)
              else
                QueueList(queued: queued, library: library),
            ],
          ),
        );
      },
    );
  }
}
