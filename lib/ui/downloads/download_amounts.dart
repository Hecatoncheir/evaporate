import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';

/// Сколько скачано, сколько всего и какая доля готова.
class DownloadAmounts extends StatelessWidget {
  const DownloadAmounts({
    super.key,
    required this.task,
    required this.indeterminate,
  });

  final DownloadTask task;

  /// Размер раздачи ещё неизвестен — доли готовности нет.
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            task.isMetadata
                ? l.fetchingMetadata
                : '${bytesLabel(L.of(context), task.completedBytes)} / '
                      '${bytesLabel(L.of(context), task.totalBytes)}',
            style: context.text.captionMuted.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (!indeterminate)
          Text(
            '${(task.progress * 100).round()}%',
            style: context.text.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}
