import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/readout_panel.dart';

/// Показания движка: то, на что смотрят первым делом.
class DownloadsReadout extends StatelessWidget {
  const DownloadsReadout({
    super.key,
    required this.stats,
    required this.active,
    required this.queued,
    required this.maxConcurrent,
  });

  final EngineStats stats;

  /// Задачи, занимающие слоты.
  final int active;
  final int queued;
  final int maxConcurrent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = context.colors;
    final moving = stats.downloadSpeed > 0;
    return ReadoutPanel(
      cells: [
        ReadoutCell(
          label: l.networkSpeed,
          value: speedLabel(l, stats.downloadSpeed),
          // Идущая загрузка горит фирменным цветом, замершая — нет: это и
          // есть ответ на «качается или встало».
          color: moving ? colors.primary : null,
          dim: !moving,
        ),
        ReadoutCell(
          label: l.uploadSpeed,
          value: speedLabel(l, stats.uploadSpeed),
          dim: stats.uploadSpeed == 0,
        ),
        ReadoutCell(
          label: l.downloadsStatActive,
          value: '$active / $maxConcurrent',
          compact: true,
        ),
        ReadoutCell(
          label: l.downloadsStatQueued,
          value: '$queued',
          dim: queued == 0,
        ),
      ],
    );
  }
}
