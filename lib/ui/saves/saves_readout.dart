import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../labels.dart';
import '../widgets/readout_cell.dart';
import '../widgets/readout_panel.dart';
import 'snapshot_history.dart';

/// Показания хранилища снимков: что спрашивают в первую очередь.
class SavesReadout extends StatelessWidget {
  const SavesReadout({
    super.key,
    required this.entries,
    required this.configured,
  });

  /// Все снимки библиотеки, свежие сверху.
  final List<SnapshotEntry> entries;

  /// Сколько игр знают, где лежат их сохранения.
  final int configured;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final stored = entries.fold<int>(0, (sum, e) => sum + e.$2.sizeBytes);
    final last = entries.isEmpty ? null : entries.first.$2.createdAt;
    return ReadoutPanel(
      cells: [
        ReadoutCell(label: l.savesStatSnapshots, value: '${entries.length}'),
        ReadoutCell(
          label: l.savesStatSize,
          value: bytesLabel(L.of(context), stored),
        ),
        ReadoutCell(label: l.savesStatGames, value: '$configured'),
        ReadoutCell(
          label: l.savesStatLast,
          value: last == null
              ? l.savesStatNever
              : dateTimeLabel(L.of(context), last),
          // Дата длиннее числа и в тот же кегль не влезает.
          compact: true,
          dim: last == null,
        ),
      ],
    );
  }
}
