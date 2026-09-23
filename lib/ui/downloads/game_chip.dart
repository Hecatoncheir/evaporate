import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../theme.dart';
import '../widgets/hover_builder.dart';
import '../widgets/inset_tile.dart';
import 'remove_from_library_button.dart';

/// Плашка игры, которую можно утащить в очередь.
///
/// Плашку тащат мышью, и это должно быть видно до того, как потянут: под
/// курсором она приподнимается и берёт фирменный кант.
class GameChip extends StatelessWidget {
  const GameChip({super.key, required this.game});

  final Game game;

  /// Подъём под курсором — доля высоты плашки, около двух точек.
  static const _lift = Offset(0, -0.05);

  @override
  Widget build(BuildContext context) => HoverBuilder(
    builder: (context, hovered, _) => AnimatedSlide(
      offset: hovered ? _lift : Offset.zero,
      duration: context.motion.fast,
      curve: EvaporateMotion.ease,
      child: InsetTile(
        hovered: hovered,
        margin: EdgeInsets.zero,
        child: _ChipRow(game: game, hovered: hovered),
      ),
    ),
  );
}

/// Ручка, название и клавиша удаления.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.game, required this.hovered});

  final Game game;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(
          Icons.drag_indicator,
          size: EvaporateIconSize.key,
          color: hovered ? colors.primary : colors.textSecondary,
        ),
        const SizedBox(width: EvaporateSpacing.gap),
        Expanded(
          child: Text(
            game.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.body,
          ),
        ),
        // Убрать игру можно и отсюда: список этот для многих — единственное
        // место, где неустановленная игра вообще видна, и гонять за
        // удалением на её страницу незачем. Клавиша видна всегда, а не по
        // наведению: спрятанное под курсором не существует для того, кто
        // о нём не знает.
        const SizedBox(width: EvaporateSpacing.line),
        RemoveFromLibraryButton(game: game),
      ],
    );
  }
}
