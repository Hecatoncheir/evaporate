import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../theme.dart';

/// Надстрочная метка: чем игра занята и сколько в неё играли.
class FeaturedEyebrow extends StatelessWidget {
  const FeaturedEyebrow({
    super.key,
    required this.game,
    this.withPlaytime = false,
  });

  final Game game;
  final bool withPlaytime;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    var text = l.featuredContinue(
      game.play.lastPlayed == null ? l.featuredReady : l.featuredRecent,
    );
    if (withPlaytime && game.play.playtime > Duration.zero) {
      text = '$text · ${formatDurationLabel(l, game.play.playtime)}';
    }
    return Row(
      children: [
        Container(width: 22, height: 1.5, color: AppColors.heroEyebrow),
        const SizedBox(width: EvaporateSpacing.gap),
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.label.copyWith(color: AppColors.heroEyebrow),
          ),
        ),
      ],
    );
  }
}
