import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_snapshot.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/inset_tile.dart';
import 'save_tag.dart';

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
        formatDateTime(snapshot.createdAt),
        snapshotOriginLabel(l, snapshot.origin),
        snapshot.fileCount,
      ),
      child: InsetTile(
        child: Row(
          children: [
            Expanded(child: ExcludeSemantics(child: _summary(context))),
            _action(
              icon: Icons.restore,
              tooltip: l.restore,
              onPressed: onRestore,
            ),
            _action(
              icon: Icons.ios_share,
              tooltip: l.exportFile,
              onPressed: onExport,
            ),
            _action(
              icon: Icons.delete_outline,
              tooltip: l.delete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  /// Когда сняли, откуда он взялся и что в нём лежит.
  Widget _summary(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              formatDateTime(snapshot.createdAt),
              style: context.text.bodyStrong,
            ),
            const SizedBox(width: 8),
            SaveTag(
              text: snapshotOriginLabel(l, snapshot.origin),
              color: snapshot.origin == SnapshotOrigin.imported
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${snapshot.deviceName} · '
          '${platformLabel(snapshot.platform)} · '
          '${l.filesCount(snapshot.fileCount)} · '
          '${formatBytes(snapshot.sizeBytes)}',
          style: context.text.captionMuted,
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
  );
}
