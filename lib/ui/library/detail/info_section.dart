import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/download/torrent_export.dart';
import '../../feedback/snack.dart';
import '../../labels.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final source = game.source;
    return SectionCard(
      title: L.of(context).details,
      icon: Icons.info_outline,
      child: Column(
        children: [
          InfoRow(
            label: L.of(context).playtimeLabel,
            value: game.playtime.inMinutes > 0
                ? formatDurationLabel(L.of(context), game.playtime)
                : L.of(context).neverPlayed,
          ),
          InfoRow(
            label: L.of(context).lastLaunch,
            value: game.lastPlayed == null
                ? '—'
                : formatDateTime(game.lastPlayed!),
          ),
          InfoRow(
            label: L.of(context).added,
            value: formatDateTime(game.addedAt),
          ),
          if (game.sizeBytes > 0)
            InfoRow(
              label: L.of(context).sizeLabel,
              value: formatBytes(game.sizeBytes),
            ),
          if (game.steamAppId != null)
            InfoRow(label: 'Steam', value: 'appid ${game.steamAppId}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Папка игры живёт здесь, рядом с остальными сведениями о
                // ней: в ряду действий её место заняли клавиши Steam, а
                // открыть папку — дело справочное, а не главное.
                if (game.isInstalled && game.canLaunch)
                  OutlinedButton.icon(
                    onPressed: () => _openInstallDir(context),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: Text(L.of(context).gameFolder2),
                  ),
                // Игру принёс торрент — значит, есть что унести обратно.
                if (TorrentExport.isTorrent(game))
                  OutlinedButton.icon(
                    onPressed: () => _exportTorrent(context),
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: Text(L.of(context).exportTorrent),
                  ),
              ],
            ),
          ),
          if (source != null)
            InfoRow(
              label: L.of(context).source,
              value: source.kind == GameSourceKind.magnet
                  ? '${source.label}: ${_shorten(source.value)}'
                  : '${source.label}: ${source.value}',
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

  Future<void> _openInstallDir(BuildContext context) async {
    final dir = game.installDir;
    if (dir == null) return;
    final command = Platform.isMacOS
        ? 'open'
        : (Platform.isWindows ? 'explorer' : 'xdg-open');
    try {
      await Process.run(command, [dir]);
    } on ProcessException catch (error) {
      if (context.mounted) showError(context, error.message);
    }
  }

  static String _shorten(String value) =>
      value.length <= 72 ? value : '${value.substring(0, 72)}…';
}
