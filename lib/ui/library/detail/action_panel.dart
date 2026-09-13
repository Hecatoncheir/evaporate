import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../../services/launch/executable_finder.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../play_button.dart';
import '../../widgets/animated_progress.dart';
import '../../../l10n/app_localizations.dart';

/// Главная кнопка карточки плюс прогресс загрузки.
///
/// Занятость приходит из состояния блока: виджету больше не нужен свой
/// флаг и `try/catch` — ошибки показывает общий слушатель в оболочке.
class ActionPanel extends StatelessWidget {
  const ActionPanel({super.key, required this.game, required this.task});

  final Game game;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.launchKey(game.id)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: _buildRow(context, busy)),
            if (task != null && task!.state != DownloadState.complete) ...[
              const SizedBox(height: 16),
              ProgressBlock(task: task!),
            ],
            if (game.status == GameStatus.error && game.lastError != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: context.colors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.lastError!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.danger,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ряд действий: слева — то, что делают с самой игрой, справа — то, что
  /// делают с её ярлыком в Steam.
  List<Widget> _buildRow(BuildContext context, bool busy) {
    return [
      ..._primaryActions(context, busy),
      // Правая половина забирает всё оставшееся место и прижимает клавиши
      // к краю. Распорка тут не годится, хотя напрашивается: она делила бы
      // свободное место с ними поровну, и подписи переносились бы на
      // вторую строку при живом пустом месте слева.
      //
      // Wrap внутри — на случай, когда места и правда мало: подписи у
      // Steam длинные, и в узком окне две клавиши рядом с «Играть»
      // переполнили бы ряд полосатой лентой.
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (game.canLaunch) _SteamShortcutButton(game: game),
              _SteamLookupButton(game: game),
            ],
          ),
        ),
      ),
    ];
  }

  /// Действия над самой игрой — левая половина ряда.
  List<Widget> _primaryActions(BuildContext context, bool busy) {
    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();

    if (game.status == GameStatus.running) {
      return [
        OutlinedButton.icon(
          onPressed: () => library.add(GameStopRequested(game)),
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(L.of(context).stop),
        ),
        const SizedBox(width: 14),
        Text(
          L.of(context).gameRunning,
          style: TextStyle(color: context.colors.accent, fontSize: 13),
        ),
      ];
    }

    if (game.status == GameStatus.downloading ||
        game.status == GameStatus.paused) {
      final paused = game.status == GameStatus.paused;
      return [
        FilledButton.icon(
          onPressed: () => downloads.add(
            paused
                ? DownloadResumeRequested(game)
                : DownloadPauseRequested(game),
          ),
          icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 18),
          label: Text(paused ? L.of(context).resume : L.of(context).pause),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _cancelDownload(context),
          icon: const Icon(Icons.close, size: 17),
          label: Text(L.of(context).cancelDownload),
        ),
      ];
    }

    if (game.isInstalled) {
      return [
        PlayButton(
          onPressed: game.canLaunch && !busy
              ? () => library.add(GameLaunchRequested(game))
              : null,
          label: L.of(context).play,
        ),
        // Пояснение гибкое, а не растянутое: справа стоят клавиши Steam, и
        // растяжка отобрала бы у них половину места под пустой текст.
        if (!game.canLaunch) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              L.of(context).pickExecutableNote,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ];
    }

    // Не установлена.
    final source = game.source;
    final canDownload =
        source != null && source.kind != GameSourceKind.localFolder;
    return [
      LauncherActionButton(
        onPressed: canDownload
            ? () => downloads.add(DownloadRequested(game: game, source: source))
            : null,
        icon: Icons.download_rounded,
        label: L.of(context).download,
      ),
      const SizedBox(width: 10),
      OutlinedButton.icon(
        onPressed: () => _pickInstallDir(context),
        icon: const Icon(Icons.folder_outlined, size: 17),
        label: Text(L.of(context).setFolder),
      ),
    ];
  }

  Future<void> _cancelDownload(BuildContext context) async {
    final downloads = context.read<DownloadsBloc>();
    final ok = await confirm(
      context,
      title: L.of(context).cancelDownloadQuestion,
      message: L.of(context).cancelDownloadNote,
      confirmLabel: L.of(context).cancelDownload,
      destructive: true,
    );
    if (!ok) return;
    downloads.add(DownloadCancelRequested(game));
  }

  Future<void> _pickInstallDir(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath();
    if (dir == null) return;

    final candidates = await ExecutableFinder.scan(dir);
    library.add(
      GameUpdated(
        game.copyWith(
          installDir: dir,
          status: GameStatus.installed,
          executablePath:
              game.executablePath ??
              (candidates.isEmpty ? null : candidates.first.path),
        ),
      ),
    );
  }
}

/// «Добавить в Steam» — заводит игру сторонним ярлыком.
class _SteamShortcutButton extends StatelessWidget {
  const _SteamShortcutButton({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamShortcutKey(game.id)),
    );
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () => context.read<LibraryBloc>().add(SteamShortcutRequested(game)),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.library_add_outlined, size: 16),
      label: Text(L.of(context).steamAddAction),
    );
  }
}

/// «Найти в Steam» или «Обновить из Steam» — описание и обложка из каталога.
class _SteamLookupButton extends StatelessWidget {
  const _SteamLookupButton({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamKey(game.id)),
    );
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () => context.read<LibraryBloc>().add(SteamLookupRequested(game)),
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
  }
}

class ProgressBlock extends StatelessWidget {
  const ProgressBlock({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final indeterminate = task.isMetadata || task.totalBytes == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedProgress(
          value: indeterminate ? null : task.progress,
          height: 6,
          borderRadius: 4,
          busy: task.state == DownloadState.active,
        ),
        const SizedBox(height: 10),
        DefaultTextStyle(
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
          child: Row(
            children: [
              Text(
                task.isMetadata
                    ? L.of(context).fetchingTorrentMetadata
                    : '${(task.progress * 100).toStringAsFixed(1)}% · '
                          '${L.of(context).ofAmount(formatBytes(task.completedBytes), formatBytes(task.totalBytes))}',
              ),
              const Spacer(),
              if (!task.isMetadata) ...[
                Text(
                  '${speedLabel(L.of(context), task.downloadSpeed)} · '
                  '${L.of(context).etaLeft(formatEtaLabel(L.of(context), task.etaSeconds))}',
                ),
                const SizedBox(width: 12),
                Text(L.of(context).peersCount(task.connections)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
