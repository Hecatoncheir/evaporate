import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                game.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (game.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  game.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.paragraph,
                ),
              ],
              if (game.rating?.hasAnything ?? false) ...[
                const SizedBox(height: 8),
                RatingRow(rating: game.rating!),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusChip(status: game.status),
                  const SizedBox(width: 10),
                  if (game.playtime.inMinutes > 0)
                    Text(
                      L
                          .of(context)
                          .playtime(
                            formatDurationLabel(L.of(context), game.playtime),
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
