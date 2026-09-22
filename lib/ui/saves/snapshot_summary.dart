import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../labels.dart';
import '../library/saves/save_tag.dart';
import '../theme.dart';

/// Название игры, откуда взялся снимок, и строка показаний под ними.
class SnapshotSummary extends StatelessWidget {
  const SnapshotSummary({
    super.key,
    required this.game,
    required this.snapshot,
  });

  final Game game;
  final SaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyStrong,
              ),
            ),
            const SizedBox(width: 8),
            SaveTag(
              text: snapshotOriginLabel(L.of(context), snapshot.origin),
              color: snapshot.origin == SnapshotOrigin.imported
                  ? colors.primary
                  : colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${dateTimeLabel(L.of(context), snapshot.createdAt)} · '
          '${snapshot.deviceName} · '
          '${bytesLabel(L.of(context), snapshot.sizeBytes)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Моноширинный с табличными цифрами: иначе строка дёргалась бы
          // на каждом обновлении списка.
          style: context.text.pathSmall.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
