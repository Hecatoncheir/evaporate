import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../theme.dart';
import '../widgets/hover_builder.dart';
import 'remove_from_library_button.dart';

/// Плашка игры, которую можно утащить в очередь.
///
/// Плашку тащат мышью, и это должно быть видно до того, как потянут: под
/// курсором она приподнимается и берёт фирменный кант.
class GameChip extends StatelessWidget {
  const GameChip({super.key, required this.game});

  final Game game;

  static const _padding = EdgeInsets.symmetric(
    horizontal: EvaporateSpacing.field,
    vertical: EvaporateSpacing.cluster,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HoverBuilder(
      builder: (context, hovered, _) => AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
        padding: _padding,
        decoration: BoxDecoration(
          color: hovered
              ? Color.lerp(colors.surface, colors.primary, 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          border: Border.all(
            color: hovered
                ? colors.primary.withValues(alpha: EvaporateAlpha.strong)
                : colors.outline,
          ),
        ),
        child: Row(
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
            // Убрать игру можно и отсюда: список этот для многих —
            // единственное место, где неустановленная игра вообще видна, и
            // гонять за удалением на её страницу незачем. Клавиша видна
            // всегда, а не по наведению: спрятанное под курсором не
            // существует для того, кто о нём не знает.
            const SizedBox(width: EvaporateSpacing.line),
            RemoveFromLibraryButton(game: game),
          ],
        ),
      ),
    );
  }
}
