import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';

/// Показания под ходом загрузки: остаток времени, пиры, раздающие и
/// отданное — на карточке загрузки и на странице игры.
///
/// Полосу, проценты и «получаем метаданные» рисует `DownloadActivity` над
/// ними — здесь только то, чего у неё нет.
class TaskStats extends StatelessWidget {
  const TaskStats({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return DefaultTextStyle(
      style: context.text.captionMuted,
      child: Wrap(
        spacing: EvaporateSpacing.field,
        runSpacing: EvaporateSpacing.tight,
        children: [
          if (!task.isMetadata && task.etaSeconds > 0)
            Text(l.etaLeft(formatEtaLabel(l, task.etaSeconds))),
          Text(l.peersCount(task.connections)),
          if (task.seeders > 0) Text(l.seedsCount(task.seeders)),
          // Отданное показываем всегда, когда оно есть: раздача — плата за
          // скачанное, и знать свой вклад пользователь вправе.
          if (task.uploadedBytes > 0) ...[
            Text(l.uploadedTotal(bytesLabel(l, task.uploadedBytes))),
            if (task.completedBytes > 0) Text(l.ratioValue(_ratio)),
          ],
        ],
      ),
    );
  }

  /// Сколько отдано на каждый скачанный байт.
  String get _ratio =>
      (task.uploadedBytes / task.completedBytes).toStringAsFixed(2);
}
