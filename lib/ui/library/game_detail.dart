import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'detail/action_panel.dart';
import 'detail/detail_header.dart';
import 'detail/downloading_header.dart';
import 'detail/files_section.dart';
import 'detail/info_section.dart';
import 'remove_game_button.dart';
import 'saves/save_paths_section.dart';
import 'saves/snapshots_section.dart';

/// Карточка игры целиком: заголовок, действия, сохранения, файлы и
/// сведения — одной прокручиваемой колонкой.
///
/// Страница занимает всё окно, а строка длиной в тысячу точек не читается —
/// колонка держится в разумной ширине и стоит по центру.
class GameDetail extends StatelessWidget {
  const GameDetail({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    // Истории скоростей здесь больше не заводятся: она одна на приложение
    // (`DownloadHistoryBloc`), и график с показаниями берут её по задаче.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          padding: EvaporateLayout.pagePadding,
          children: [
            if (task != null && !task.isFinished)
              DownloadingHeader(game: game, task: task)
            else
              DetailHeader(game: game),
            const SizedBox(height: EvaporateSpacing.section),
            ActionPanel(game: game, task: task),
            const SizedBox(height: EvaporateSpacing.wide),
            SavePathsSection(game: game),
            SnapshotsSection(game: game),
            FilesSection(game: game),
            InfoSection(game: game),
            const SizedBox(height: EvaporateSpacing.gap),
            RemoveGameButton(game: game),
          ],
        ),
      ),
    );
  }
}
