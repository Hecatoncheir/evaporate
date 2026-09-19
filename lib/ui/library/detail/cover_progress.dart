import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/animated_progress.dart';

/// Полоса прогресса поверх обложки.
class CoverProgress extends StatelessWidget {
  const CoverProgress({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    // У метаданных и у задачи в очереди процента ещё нет — показываем статус.
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = downloadProgressShort(L.of(context), task);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        // Затемнение и белый текст здесь не из палитры и не должны в неё
        // уходить: подложка — обложка игры, а не фон приложения, и на
        // светлой теме она остаётся такой же тёмной.
        color: AppColors.detailOverlay,
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.tag.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.coverText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedProgress(
              value: indeterminate ? null : task.progress,
              height: 3,
              borderRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
