import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/animated_progress.dart';
import 'download_amounts.dart';
import 'download_chart.dart';
import 'download_metrics.dart';

/// Показания одной загрузки: скорость, пик, диск, отдача — и сколько
/// скачано из скольких.
///
/// График сюда входит не всегда: на странице игры он уехал подложкой под
/// заголовок, и рисовать его ещё раз здесь незачем.
class DownloadActivity extends StatelessWidget {
  const DownloadActivity({
    super.key,
    required this.task,
    this.showChart = true,
  });

  final DownloadTask task;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Пока метаданных нет, размер раздачи неизвестен, и доля готовности
    // тоже: полоса в этом случае бежит без конца, а не стоит на нуле.
    final indeterminate = task.isMetadata || task.totalBytes == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DownloadMetrics(task: task),
        if (showChart) ...[
          const SizedBox(height: EvaporateSpacing.block),
          DownloadChart(task: task),
        ],
        const SizedBox(height: EvaporateSpacing.block),
        DownloadAmounts(task: task, indeterminate: indeterminate),
        const SizedBox(height: EvaporateSpacing.tight),
        Semantics(
          value: indeterminate
              ? l.fetchingMetadata
              : percentLabel(l, task.progress),
          child: AnimatedProgress(
            value: indeterminate ? null : task.progress,
            height: 6,
            borderRadius: EvaporateTheme.radiusChip,
            busy: task.state == DownloadState.active,
          ),
        ),
      ],
    );
  }
}
