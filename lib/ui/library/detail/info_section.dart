import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import 'game_file_actions.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final source = game.download.source;
    return SectionCard(
      title: L.of(context).details,
      icon: Icons.info_outline,
      child: Column(
        children: [
          InfoRow(
            label: L.of(context).playtimeLabel,
            value: game.play.playtime.inMinutes > 0
                ? formatDurationLabel(L.of(context), game.play.playtime)
                : L.of(context).neverPlayed,
          ),
          InfoRow(
            label: L.of(context).lastLaunch,
            value: game.play.lastPlayed == null
                ? '—'
                : formatDateTime(game.play.lastPlayed!),
          ),
          InfoRow(
            label: L.of(context).added,
            value: formatDateTime(game.addedAt),
          ),
          if (game.sizeBytes > 0)
            InfoRow(
              label: L.of(context).sizeLabel,
              value: formatBytes(game.sizeBytes),
            ),
          if (game.details.steamAppId != null)
            InfoRow(label: 'Steam', value: 'appid ${game.details.steamAppId}'),
          const SizedBox(height: 10),
          GameFileActions(game: game),
          if (source != null)
            InfoRow(
              label: L.of(context).source,
              value: source.kind == GameSourceKind.magnet
                  ? '${source.label}: ${_shorten(source.value)}'
                  : '${source.label}: ${source.value}',
            ),
        ],
      ),
    );
  }

  static String _shorten(String value) =>
      value.length <= 72 ? value : '${value.substring(0, 72)}…';
}
