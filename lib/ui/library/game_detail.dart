import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'saves_section.dart';
import '../../l10n/app_localizations.dart';
import '../downloads/download_activity.dart';
import 'detail/action_panel.dart';
import 'detail/downloading_header.dart';
import 'detail/detail_header.dart';
import 'detail/files_section.dart';
import 'detail/info_section.dart';

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
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
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
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
              ),
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
    final hasFiles =
        game.installDir != null && Directory(game.installDir!).existsSync();

    final choice = await showDialog<_RemoveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).removeQuestion(game.title)),
        content: Text(
          hasFiles
              ? '${L.of(context).removeSnapshotsNote}\n\n'
                    '${L.of(context).removeFilesNote(game.installDir!)}'
              : L.of(context).removeSnapshotsNote,
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.of(context).cancel),
          ),
          if (hasFiles)
            TextButton(
              onPressed: () => Navigator.pop(context, _RemoveChoice.withFiles),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
              ),
              child: Text(L.of(context).removeWithFiles),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _RemoveChoice.libraryOnly),
            child: Text(L.of(context).removeFromLibrary),
          ),
        ],
      ),
    );
    if (choice == null) return;
    library.add(
      GameRemoved(game, deleteFiles: choice == _RemoveChoice.withFiles),
    );
  }
}

enum _RemoveChoice { libraryOnly, withFiles }
