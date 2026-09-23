import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_snapshot.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'save_tag.dart';

/// Снимок в списке: заголовок, откуда снимок взялся, и строка показаний.
///
/// На странице игры заголовок — дата: игра и так понятна. В общем списке
/// снимков разных игр заголовок — [gameTitle], а дата уходит в строку ниже.
class SnapshotSummary extends StatelessWidget {
  const SnapshotSummary({super.key, required this.snapshot, this.gameTitle});

  final SaveSnapshot snapshot;
  final String? gameTitle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final when = dateTimeLabel(l, snapshot.createdAt);
    final details = [
      if (gameTitle != null) when,
      snapshot.deviceName,
      if (gameTitle == null) ...[
        platformLabel(snapshot.platform),
        l.filesCount(snapshot.fileCount),
      ],
      bytesLabel(l, snapshot.sizeBytes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                gameTitle ?? when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyStrong,
              ),
            ),
            const SizedBox(width: EvaporateSpacing.gap),
            SaveTag(
              text: snapshotOriginLabel(l, snapshot.origin),
              // Привезённое с другого устройства выделено: его сняли не
              // здесь, и прежде восстановления это стоит заметить.
              color: snapshot.origin == SnapshotOrigin.imported
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: EvaporateSpacing.line),
        Text(
          details.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Моноширинный с табличными цифрами: иначе строка дёргалась бы
          // на каждом обновлении списка.
          style: context.text.pathSmall,
        ),
      ],
    );
  }
}
