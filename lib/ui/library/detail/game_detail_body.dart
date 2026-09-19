import 'package:flutter/material.dart';

import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../remove_game_button.dart';
import '../saves/save_paths_section.dart';
import '../saves/snapshots_section.dart';
import 'action_panel.dart';
import 'detail_header.dart';
import 'downloading_header.dart';
import 'files_section.dart';
import 'info_section.dart';

/// Содержимое страницы игры: заголовок, действия, сохранения, файлы и
/// сведения — одной прокручиваемой колонкой.
class GameDetailBody extends StatelessWidget {
  const GameDetailBody({super.key, required this.game, required this.task});

  final Game game;

  /// Задача загрузки этой игры, если она идёт.
  final DownloadTask? task;

  bool get _downloading => task != null && !task!.isFinished;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EvaporateLayout.pagePadding,
      children: [
        if (_downloading)
          DownloadingHeader(game: game, task: task!)
        else
          DetailHeader(game: game),
        const SizedBox(height: 20),
        ActionPanel(game: game, task: task),
        const SizedBox(height: 24),
        SavePathsSection(game: game),
        SnapshotsSection(game: game),
        FilesSection(game: game),
        InfoSection(game: game),
        const SizedBox(height: 8),
        RemoveGameButton(game: game),
      ],
    );
  }
}
