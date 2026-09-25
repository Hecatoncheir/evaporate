import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/animated_progress.dart';

/// Полоса загрузки поверх нижнего края обложки — на плитке сетки и на
/// маленькой обложке страницы игры.
///
/// Затемнение и белый текст здесь не из палитры и не должны в неё уходить:
/// подложка — обложка игры, а не фон приложения, и на светлой схеме она
/// остаётся такой же тёмной.
class CoverProgressStrip extends StatelessWidget {
  const CoverProgressStrip({
    super.key,
    required this.task,
    this.compact = false,
  });

  final DownloadTask task;

  /// Обложка страницы игры — 64 точки в высоту: поля и подпись мельче.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // У метаданных и у задачи в очереди процента ещё нет — показываем статус.
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = downloadProgressShort(L.of(context), task);
    final style = compact ? context.text.tagStrong : context.text.chip;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: AppColors.coverOverlay,
        padding: compact
            ? const EdgeInsets.symmetric(
                horizontal: EvaporateSpacing.tight,
                vertical: EvaporateSpacing.line,
              )
            : const EdgeInsets.symmetric(
                horizontal: EvaporateSpacing.gap,
                vertical: EvaporateSpacing.tight,
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: style.copyWith(color: AppColors.coverText),
            ),
            const SizedBox(height: EvaporateSpacing.line),
            AnimatedProgress(
              value: indeterminate ? null : task.progress,
              height: 3,
              track: AppColors.coverProgressTrack,
            ),
          ],
        ),
      ),
    );
  }
}
