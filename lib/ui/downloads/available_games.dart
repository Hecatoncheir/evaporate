import 'package:flutter/material.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../theme.dart';
import 'draggable_game.dart';
import 'section_title.dart';

/// Левая колонка: игры, которые можно поставить в очередь.
class AvailableGames extends StatelessWidget {
  const AvailableGames({super.key, required this.library, required this.tasks});

  final LibraryState library;
  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    final available = library.downloadable(tasks.map((task) => task.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EvaporateSpacing.wide,
            EvaporateSpacing.line,
            EvaporateSpacing.panel,
            0,
          ),
          child: SectionTitle(
            L.of(context).availableToDownload,
            trailing: '${available.length}',
          ),
        ),
        Expanded(
          child: available.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EvaporateSpacing.wide,
                    0,
                    EvaporateSpacing.panel,
                    EvaporateSpacing.panel,
                  ),
                  child: Text(
                    L.of(context).allGamesQueued,
                    style: context.text.paragraph,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    EvaporateSpacing.wide,
                    0,
                    EvaporateSpacing.panel,
                    EvaporateSpacing.panel,
                  ),
                  itemCount: available.length,
                  itemBuilder: (context, index) =>
                      DraggableGame(game: available[index]),
                ),
        ),
      ],
    );
  }
}
