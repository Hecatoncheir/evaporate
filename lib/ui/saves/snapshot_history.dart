import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import 'snapshot_row.dart';

/// Снимок вместе с игрой, которой он принадлежит.
///
/// Список на этом экране общий на всю библиотеку, и одного снимка для
/// строки мало: название игры лежит в игре, а не в нём.
typedef SnapshotEntry = (Game game, SaveSnapshot snapshot);

/// Хронология: все снимки библиотеки, свежие сверху.
class SnapshotsCard extends StatelessWidget {
  const SnapshotsCard({super.key, required this.entries});

  final List<SnapshotEntry> entries;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: L.of(context).allSnapshots,
    icon: Icons.history,
    trailing: Text(
      '${entries.length}',
      style: context.text.figure.copyWith(color: context.colors.textSecondary),
    ),
    child: entries.isEmpty
        ? Text(L.of(context).noSnapshotsYet, style: context.text.paragraph)
        : Column(
            children: [
              for (final (game, snapshot) in entries)
                SnapshotRow(game: game, snapshot: snapshot),
            ],
          ),
  );
}
