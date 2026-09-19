import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../labels.dart';
import '../../theme.dart';

/// Полоса загрузки поверх нижнего края обложки.
class CoverProgressStrip extends StatelessWidget {
  const CoverProgressStrip({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = downloadProgressShort(L.of(context), task);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: AppColors.coverOverlay,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.text.chip.copyWith(color: AppColors.coverText),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
              child: LinearProgressIndicator(
                value: indeterminate ? null : task.progress,
                minHeight: 3,
                backgroundColor: AppColors.coverProgressTrack,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
