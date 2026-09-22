import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../theme.dart';
import '../widgets/glass_sliver.dart';
import '../widgets/section_card_header.dart';
import 'snapshot_row.dart';

/// Снимок вместе с игрой, которой он принадлежит.
///
/// Список на этом экране общий на всю библиотеку, и одного снимка для
/// строки мало: название игры лежит в игре, а не в нём.
typedef SnapshotEntry = (Game game, SaveSnapshot snapshot);

/// Хронология: все снимки библиотеки, свежие сверху.
///
/// Сливер, а не карточка-коробка. Снимков по двадцать на игру, и в
/// сложившейся библиотеке строк сотни, а видно из них полтора десятка:
/// `Column` строила и раскладывала все на каждую пересборку, а
/// перерисовка одной строки под курсором переписывала слой целиком.
/// Строки строит `SliverList` по мере прокрутки; карточка вокруг — то же
/// стекло, что у соседних, только сливером ([GlassSliver]).
class SnapshotHistory extends StatelessWidget {
  const SnapshotHistory({super.key, required this.entries});

  final List<SnapshotEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: EvaporateSpacing.panel),
      sliver: GlassSliver(
        radius: EvaporateTheme.radiusPanel,
        opacity: HardwareSurfaceTheme.of(context).cardOpacity,
        padding: const EdgeInsets.all(EvaporateSpacing.card),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: SectionCardHeader(
                title: l.allSnapshots,
                icon: Icons.history,
                trailing: Text(
                  '${entries.length}',
                  style: context.text.figure.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverToBoxAdapter(
                child: Text(l.noSnapshotsYet, style: context.text.paragraph),
              )
            else
              SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) =>
                    SnapshotRow(game: entries[i].$1, snapshot: entries[i].$2),
              ),
          ],
        ),
      ),
    );
  }
}
