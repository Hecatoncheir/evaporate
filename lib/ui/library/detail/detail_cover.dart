import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import 'cover_progress.dart';

/// Обложка из Steam, если её удалось найти; иначе — первая буква названия.
///
/// Пока игра качается, поверх обложки идёт полоса прогресса с процентом:
/// состояние загрузки видно сразу, не вчитываясь в панель ниже.
class DetailCover extends StatelessWidget {
  const DetailCover({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final path = game.details.coverPath;
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final showProgress = task != null && !task.isFinished;

    return Container(
      width: path == null ? 64 : 132,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
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
