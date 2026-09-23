import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/toned_chip.dart';
import 'detail_cover.dart';
import 'rating_row.dart';

class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailCover(game: game),
        const SizedBox(width: EvaporateSpacing.panel),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(game.title, style: context.text.pageTitle),
              if (game.details.description != null) ...[
                const SizedBox(height: EvaporateSpacing.gap),
                Text(
                  game.details.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.paragraph,
                ),
              ],
              if (game.details.rating?.hasAnything ?? false) ...[
                const SizedBox(height: EvaporateSpacing.gap),
                RatingRow(rating: game.details.rating!),
              ],
              const SizedBox(height: EvaporateSpacing.gap),
              Row(
                children: [
                  _StatusChip(status: game.status),
                  const SizedBox(width: EvaporateSpacing.cluster),
                  if (game.play.playtime.inMinutes > 0)
                    Text(
                      L
                          .of(context)
                          .playtime(
                            formatDurationLabel(
                              L.of(context),
                              game.play.playtime,
                            ),
                          ),
                      style: context.text.note,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Цветная метка статуса игры.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    final label = gameStatusLabel(L.of(context), status);
    final color = switch (status) {
      GameStatus.notInstalled => context.colors.textSecondary,
      GameStatus.downloading => context.colors.primary,
      GameStatus.paused => context.colors.warning,
      GameStatus.installed => context.colors.accent,
      GameStatus.running => context.colors.accent,
      GameStatus.error => context.colors.danger,
    };

    return TonedChip(
      text: label,
      color: color,
      style: context.text.captionStrong,
      padding: const EdgeInsets.symmetric(
        horizontal: EvaporateSpacing.cluster,
        vertical: EvaporateSpacing.line,
      ),
    );
  }
}
