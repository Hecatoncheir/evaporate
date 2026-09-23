import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_snapshot.dart';
import '../../labels.dart';
import '../../widgets/inset_tile.dart';
import '../../widgets/tile_icon_button.dart';
import 'snapshot_summary.dart';

class SnapshotTile extends StatelessWidget {
  const SnapshotTile({
    super.key,
    required this.snapshot,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  final SaveSnapshot snapshot;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Дата, источник, размер и число файлов лежат отдельными подписями, и
    // диктор читал бы их четырьмя объявлениями подряд. Кнопки при этом
    // остаются своими: до них надо доходить и нажимать по отдельности.
    //
    // Отсюда и место `ExcludeSemantics` — внутри строки, вокруг одних
    // подписей. Снаружи, на всей плитке, он унёс бы вместе с лишними
    // объявлениями и три действия: та же ловушка, на которой уже теряла
    // нажатие плитка игры. А без него подпись не заменяет детей, а лишь
    // встаёт перед ними, и диктор читает всё то же самое — только теперь
    // пять раз вместо четырёх.
    return Semantics(
      label: l.snapshotSpoken(
        dateTimeLabel(L.of(context), snapshot.createdAt),
        snapshotOriginLabel(l, snapshot.origin),
        snapshot.fileCount,
      ),
      child: InsetTile(
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: SnapshotSummary(snapshot: snapshot),
              ),
            ),
            TileIconButton(
              icon: Icons.restore,
              tooltip: l.restore,
              onPressed: onRestore,
            ),
            TileIconButton(
              icon: Icons.ios_share,
              tooltip: l.exportFile,
              onPressed: onExport,
            ),
            TileIconButton(
              icon: Icons.delete_outline,
              tooltip: l.delete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
