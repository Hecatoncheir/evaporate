import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../models/save_snapshot.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../../l10n/app_localizations.dart';
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
    // Дата, источник, размер и число файлов лежат отдельными подписями, и
    // диктор читал бы их четырьмя объявлениями подряд. Кнопки при этом
    // остаются своими: до них надо доходить и нажимать по отдельности.
    return Semantics(
      label: L
          .of(context)
          .snapshotSpoken(
            formatDateTime(snapshot.createdAt),
            snapshotOriginLabel(L.of(context), snapshot.origin),
            snapshot.fileCount,
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          border: Border.all(color: context.colors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatDateTime(snapshot.createdAt),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SaveTag(
                        text: snapshotOriginLabel(
                          L.of(context),
                          snapshot.origin,
                        ),
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
                    '${L.of(context).filesCount(snapshot.fileCount)} · '
                    '${formatBytes(snapshot.sizeBytes)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRestore,
              icon: const Icon(Icons.restore, size: 17),
              tooltip: L.of(context).restore,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onExport,
              icon: const Icon(Icons.ios_share, size: 17),
              tooltip: L.of(context).exportFile,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 17),
              tooltip: L.of(context).delete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
