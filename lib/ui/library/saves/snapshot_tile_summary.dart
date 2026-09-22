import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_snapshot.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'save_tag.dart';

/// Снимок в списке игры: когда сняли, откуда он взялся и что в нём лежит.
class SnapshotTileSummary extends StatelessWidget {
  const SnapshotTileSummary({super.key, required this.snapshot});

  final SaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              dateTimeLabel(L.of(context), snapshot.createdAt),
              style: context.text.bodyStrong,
            ),
            const SizedBox(width: EvaporateSpacing.gap),
            SaveTag(
              text: snapshotOriginLabel(l, snapshot.origin),
              color: snapshot.origin == SnapshotOrigin.imported
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: EvaporateSpacing.line),
        Text(
          '${snapshot.deviceName} · '
          '${platformLabel(snapshot.platform)} · '
          '${l.filesCount(snapshot.fileCount)} · '
          '${bytesLabel(L.of(context), snapshot.sizeBytes)}',
          style: context.text.captionMuted,
        ),
      ],
    );
  }
}
