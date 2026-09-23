import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../library/saves/snapshot_actions.dart';
import '../library/saves/snapshot_summary.dart';
import '../theme.dart';
import '../widgets/hover_builder.dart';
import '../widgets/inset_tile.dart';
import '../widgets/tile_icon_button.dart';

/// Строка снимка: чья игра, когда снят, чем снят — и что с ним можно сделать.
///
/// Под курсором строка подсвечивается: действия у неё по краю, и без
/// подсветки в длинном списке легко нажать «удалить» у соседнего снимка.
class SnapshotRow extends StatelessWidget {
  const SnapshotRow({super.key, required this.game, required this.snapshot});

  final Game game;
  final SaveSnapshot snapshot;

  /// Справа уже: там клавиши со своим полем вокруг значка.
  static const _padding = EdgeInsets.fromLTRB(
    EvaporateSpacing.field,
    EvaporateSpacing.gap,
    EvaporateSpacing.tight,
    EvaporateSpacing.gap,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = L.of(context);

    return HoverBuilder(
      child: SnapshotSummary(snapshot: snapshot, gameTitle: game.title),
      builder: (context, hovered, summary) => InsetTile(
        hovered: hovered,
        padding: _padding,
        child: Row(
          children: [
            Expanded(child: summary!),
            TileIconButton(
              icon: Icons.ios_share,
              tooltip: l.exportFile,
              onPressed: () => exportSnapshot(context, snapshot),
            ),
            TileIconButton(
              icon: Icons.delete_outline,
              tooltip: l.delete,
              // Тревожный цвет — только под курсором: ряд постоянно красных
              // корзин в списке читается как список ошибок.
              color: hovered ? colors.danger : colors.textSecondary,
              onPressed: () => deleteSnapshot(context, game, snapshot),
            ),
          ],
        ),
      ),
    );
  }
}
