import 'package:flutter/material.dart';

import '../../bloc/library/library_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';

/// Левая колонка: игры, которые можно поставить в очередь.
class AvailableGames extends StatelessWidget {
  const AvailableGames({super.key, required this.library, required this.tasks});

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
                      DraggableGame(game: available[index]),
                ),
        ),
      ],
    );
  }
}

class DraggableGame extends StatelessWidget {
  const DraggableGame({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final tile = GameChip(game: game);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<Game>(
        data: game,
        feedback: Material(
          color: AppColors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(width: 250, child: GameChip(game: game)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        child: tile,
      ),
    );
  }
}

class GameChip extends StatelessWidget {
  const GameChip({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
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
