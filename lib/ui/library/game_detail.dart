import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../downloads/download_activity.dart';
import '../theme.dart';
import 'detail/action_panel.dart';
import 'detail/detail_header.dart';
import 'detail/downloading_header.dart';
import 'detail/files_section.dart';
import 'detail/info_section.dart';
import 'remove_game_dialog.dart';
import 'saves_section.dart';

class GameDetail extends StatelessWidget {
  const GameDetail({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );

    // Страница занимает всё окно, а строка длиной в тысячу точек не
    // читается — колонка держится в разумной ширине и стоит по центру.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: _content(context, task),
      ),
    );
  }

  Widget _content(BuildContext context, DownloadTask? task) {
    final downloading = task != null && task.state != DownloadState.complete;
    // Область истории охватывает обе половины сразу: подложку под
    // заголовком и показания у клавиш. Ключ по задаче — иначе при
    // перелистывании страниц история одной игры досталась бы другой.
    return _wrapHistory(
      task: downloading ? task : null,
      child: ListView(
        padding: EvaporateLayout.pagePadding,
        children: [
          if (downloading)
            DownloadingHeader(game: game, task: task)
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _remove(context),
              style: context.buttons.dangerText,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(L.of(context).removeFromLibrary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapHistory({required DownloadTask? task, required Widget child}) =>
      task == null
      ? child
      : DownloadHistoryScope(key: ValueKey(task.id), task: task, child: child);

  Future<void> _remove(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final choice = await askRemoveGame(context, game);
    if (choice == null) return;
    library.add(
      GameRemoved(game, deleteFiles: choice == RemoveChoice.withFiles),
    );
  }
}
