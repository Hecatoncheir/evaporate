import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../library/remove_game_dialog.dart';
import '../theme.dart';
import 'queue_column.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
          child: SectionTitle(
            L.of(context).availableToDownload,
            trailing: '${available.length}',
          ),
        ),
        Expanded(
          child: available.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                  child: Text(
                    L.of(context).allGamesQueued,
                    style: context.text.paragraph,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
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

class GameChip extends StatefulWidget {
  const GameChip({super.key, required this.game});

  final Game game;

  @override
  State<GameChip> createState() => _GameChipState();
}

class _GameChipState extends State<GameChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final game = widget.game;
    // Плашку тащат мышью, и это должно быть видно до того, как потянут:
    // под курсором она приподнимается и берёт фирменный кант.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? Color.lerp(colors.surface, colors.primary, 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          border: Border.all(
            color: _hovered
                ? colors.primary.withValues(alpha: EvaporateAlpha.strong)
                : colors.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: _hovered ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.body,
              ),
            ),
            // Убрать игру можно и отсюда: список этот для многих —
            // единственное место, где неустановленная игра вообще видна, и
            // гонять за удалением на её страницу незачем. Клавиша видна
            // всегда, а не по наведению: спрятанное под курсором не
            // существует для того, кто о нём не знает.
            const SizedBox(width: 4),
            _RemoveButton(game: game),
          ],
        ),
      ),
    );
  }
}

/// Убрать игру из списка — то есть из библиотеки.
///
/// Приглушена, пока на неё не навели: рядом с ней плашку тащат мышью, и
/// тревожный цвет во весь список спорил бы с тем, ради чего список
/// заведён.
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.game});

  final Game game;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: IconButton(
        onPressed: () => _remove(context),
        icon: const Icon(Icons.close_rounded, size: 15),
        tooltip: L.of(context).removeFromLibrary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        color: _hovered ? colors.danger : colors.textSecondary,
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final choice = await askRemoveGame(context, widget.game);
    if (choice == null) return;
    library.add(
      GameRemoved(widget.game, deleteFiles: choice == RemoveChoice.withFiles),
    );
  }
}
