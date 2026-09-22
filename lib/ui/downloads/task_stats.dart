import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';

/// Показания под графиком: раздающие, пиры, отданное и остаток времени.
class TaskStats extends StatelessWidget {
  const TaskStats({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return DefaultTextStyle(
      style: context.text.captionMuted,
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (task.seeders > 0) Text(l.seedsCount(task.seeders)),
          // Отданное показываем всегда, когда оно есть: раздача — плата за
          // скачанное, и знать свой вклад пользователь вправе.
          if (task.uploadedBytes > 0) ...[
            Text(
              l.uploadedTotal(bytesLabel(L.of(context), task.uploadedBytes)),
            ),
            if (task.completedBytes > 0) ...[
              const SizedBox(width: EvaporateSpacing.tight),
              Text(l.ratioValue(_ratio)),
            ],
          ],
          Text(l.peersCount(task.connections)),
          if (!task.isMetadata && task.etaSeconds > 0)
            Text(l.etaLeft(formatEtaLabel(l, task.etaSeconds))),
        ],
      ),
    );
  }

  /// Сколько отдано на каждый скачанный байт.
  String get _ratio =>
      (task.uploadedBytes / task.completedBytes).toStringAsFixed(2);
}
