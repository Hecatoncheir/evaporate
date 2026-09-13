import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../../widgets/animated_progress.dart';
import '../../../l10n/app_localizations.dart';

/// Обложка из Steam, если её удалось найти; иначе — первая буква названия.
///
/// Пока игра качается, поверх обложки идёт полоса прогресса с процентом:
/// состояние загрузки видно сразу, не вчитываясь в панель ниже.
class DetailCover extends StatelessWidget {
  const DetailCover({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final path = game.coverPath;
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final showProgress = task != null && task.state != DownloadState.complete;

    return Container(
      width: path == null ? 64 : 132,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.outline),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path == null)
            Center(
              child: Text(
                game.title.characters.take(1).toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
            )
          else
            Image.file(
              File(path),
              fit: BoxFit.cover,
              // Обложка — украшение: не грузится, значит её просто нет.
              errorBuilder: (context, error, stack) => Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
            ),
          if (showProgress) CoverProgress(task: task),
        ],
      ),
    );
  }
}

/// Полоса прогресса поверх обложки.
class CoverProgress extends StatelessWidget {
  const CoverProgress({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    // У метаданных и у задачи в очереди процента ещё нет — показываем статус.
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = switch (task) {
      _ when task.isQueued => L.of(context).inQueue,
      _ when task.isMetadata => L.of(context).metadataShort,
      _ when task.state == DownloadState.paused => L.of(context).pausedShort,
      _ when indeterminate => '…',
      _ => '${(task.progress * 100).toStringAsFixed(0)}%',
    };

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
              style: const TextStyle(
                fontSize: 10.5,
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
