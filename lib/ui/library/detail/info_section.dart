import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../models/game.dart';
import '../../../services/download/torrent_export.dart';
import '../../labels.dart';
import '../../widgets/common.dart';
import '../../../l10n/app_localizations.dart';

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
                Builder(
                  builder: (context) {
                    final busy = context.select<LibraryBloc, bool>(
                      (bloc) =>
                          bloc.state.isBusy(LibraryBloc.steamKey(game.id)),
                    );
                    return OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => context.read<LibraryBloc>().add(
                              SteamLookupRequested(game),
                            ),
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore, size: 16),
                      label: Text(
                        game.steamAppId == null
                            ? L.of(context).findInSteam
                            : L.of(context).refreshFromSteam,
                      ),
                    );
                  },
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

  static String _shorten(String value) =>
      value.length <= 72 ? value : '${value.substring(0, 72)}…';
}
