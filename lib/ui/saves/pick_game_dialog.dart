import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/saves/title_match.dart';
import '../theme.dart';

/// Какой игре отдать пакет с другого устройства.
///
/// Совпавшая по названию — первой и с отметкой; игры без путей сохранений
/// подписаны: пакет им лечь некуда, и узнать об этом лучше до выбора.
class PickGameDialog extends StatelessWidget {
  const PickGameDialog({super.key, required this.games, required this.title});

  final List<Game> games;

  /// Название игры в пакете.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final sorted = gamesMatchingFirst(games, title);
    return AlertDialog(
      title: Text(l.whichGameToApply),
      content: SizedBox(
        width: 460,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final game = sorted[index];
            final matches = sameGameTitle(game.title, title);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                matches
                    ? Icons.check_circle_outline
                    : Icons.videogame_asset_outlined,
                size: 18,
                color: matches ? context.colors.accent : null,
              ),
              title: Text(game.title),
              subtitle: game.saveProfile.isConfigured
                  ? null
                  : Text(
                      l.noSavePaths,
                      style: context.text.small.copyWith(
                        color: context.colors.warning,
                      ),
                    ),
              onTap: () => Navigator.pop(context, game),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
