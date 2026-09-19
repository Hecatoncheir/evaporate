import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../theme.dart';
import 'game_chip.dart';

/// Плашка игры, которую тащат из списка в очередь.
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
