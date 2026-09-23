import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';
import 'featured_actions.dart';
import 'featured_eyebrow.dart';
import 'featured_title.dart';

/// Полоса: название и клавиши в одной строке.
class FeaturedCompactBar extends StatelessWidget {
  const FeaturedCompactBar({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      EvaporateSpacing.section,
      EvaporateSpacing.panel,
      EvaporateSpacing.section,
      EvaporateSpacing.panel,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Наигранное время уходит в надстрочную метку: отдельному
              // показанию в полосе места нет, а знать его человек хочет.
              FeaturedEyebrow(game: game, withPlaytime: true),
              const SizedBox(height: EvaporateSpacing.gap),
              FeaturedTitle(game.title, compact: true),
            ],
          ),
        ),
        const SizedBox(width: EvaporateSpacing.card),
        FeaturedActions(game: game, onOpen: onOpen, onPrimary: onPrimary),
      ],
    ),
  );
}
