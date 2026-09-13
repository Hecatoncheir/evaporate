import 'dart:io';

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
            Row(children: _buildActions(context, busy)),
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

  List<Widget> _buildActions(BuildContext context, bool busy) {
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
        const SizedBox(width: 10),
        if (!game.canLaunch)
          Expanded(
            child: Text(
              L.of(context).pickExecutableNote,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _openInstallDir(context),
            icon: const Icon(Icons.folder_open, size: 17),
            label: Text(L.of(context).gameFolder2),
          ),
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
