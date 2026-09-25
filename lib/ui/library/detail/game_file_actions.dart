import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/download/torrent_export.dart';
import '../../theme.dart';

/// Что можно сделать с файлами игры: открыть её папку и унести раздачу.
///
/// Живёт в карточке сведений, а не в ряду действий: там место заняли
/// клавиши Steam, а открыть папку — дело справочное, а не главное.
class GameFileActions extends StatelessWidget {
  const GameFileActions({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: EvaporateSpacing.cluster,
        runSpacing: EvaporateSpacing.cluster,
        children: [
          if (game.isInstalled && game.canLaunch)
            OutlinedButton.icon(
              onPressed: () => context.read<LibraryBloc>().add(
                GameFolderOpenRequested(game.id),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(l.gameFolder2),
            ),
          // Игру принёс торрент — значит, есть что унести обратно.
          if (TorrentExport.isTorrent(game))
            OutlinedButton.icon(
              onPressed: () => _exportTorrent(context),
              icon: const Icon(Icons.save_alt),
              label: Text(l.exportTorrent),
            ),
        ],
      ),
    );
  }

  /// Куда положить `.torrent`, спрашиваем здесь, а ищем его — в блоке:
  /// файл может лежать и у нас, и у движка, и виджету об этом знать незачем.
  Future<void> _exportTorrent(BuildContext context) async {
    final downloads = context.read<DownloadsBloc>();
    final location = await getSaveLocation(
      suggestedName: '${safeFileName(game.title)}.torrent',
    );
    if (location == null) return;
    downloads.add(
      TorrentExportRequested(game: game, destination: location.path),
    );
  }
}
