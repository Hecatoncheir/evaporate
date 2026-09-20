import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/download_history/download_history_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';
import 'download_metric.dart';

/// Четыре показания загрузки: сеть, её пик, диск и отдача.
class DownloadMetrics extends StatelessWidget {
  const DownloadMetrics({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Историю читаем из общего Cubit: на странице игры по ней же рисуется
    // подложка под заголовком, и расходиться этим двум нельзя.
    final history = context.watch<DownloadHistoryBloc>().state;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        DownloadMetric(
          icon: Icons.network_check_rounded,
          label: l.networkSpeed,
          value: speedLabel(l, task.downloadSpeed),
          color: context.colors.primary,
        ),
        DownloadMetric(
          icon: Icons.speed_rounded,
          label: l.peakSpeed,
          value: speedLabel(l, history.peakOf(task)),
          color: context.colors.primary,
        ),
        DownloadMetric(
          icon: Icons.storage_rounded,
          label: l.diskActivity,
          value: speedLabel(l, history.diskSpeed),
          color: context.colors.accent,
        ),
        DownloadMetric(
          icon: Icons.upload_rounded,
          label: l.uploadSpeed,
          value: speedLabel(l, task.uploadSpeed),
          color: context.colors.textSecondary,
        ),
      ],
    );
  }
}
