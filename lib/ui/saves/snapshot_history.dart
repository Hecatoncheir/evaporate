import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/section_card_header.dart';
import 'sliver_glass_clip.dart';
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
/// стекло, что у соседних, только сливером ([_GlassSliver]).
class SnapshotHistory extends StatelessWidget {
  const SnapshotHistory({super.key, required this.entries});

  final List<SnapshotEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: EvaporateSpacing.panel),
      sliver: _GlassSliver(
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

/// Стекло [GlassSurface], но сливером: под длинный ленивый список.
///
/// Коробкой такой список не обернуть — он перестал бы быть ленивым и
/// строил бы все строки разом. Облик тот же до тени: заливка и тени —
/// из [GlassSurface.decorationOf], обрезка и размытие — из
/// [SliverGlassClip].
class _GlassSliver extends StatelessWidget {
  const _GlassSliver({
    required this.sliver,
    required this.radius,
    this.padding = EdgeInsets.zero,
    this.opacity,
  });

  final Widget sliver;
  final double radius;
  final EdgeInsets padding;
  final double? opacity;

  @override
  Widget build(BuildContext context) => SliverGlassClip(
    radius: radius,
    filter: GlassSurface.filterOf(GlassSurfaceTheme.of(context)),
    sliver: DecoratedSliver(
      decoration: GlassSurface.decorationOf(
        context,
        radius: radius,
        opacity: opacity,
      ),
      sliver: SliverPadding(padding: padding, sliver: sliver),
    ),
  );
}
