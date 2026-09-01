import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../services/launch/executable_finder.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'saves_section.dart';

class GameDetail extends StatelessWidget {
  const GameDetail({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        _Header(game: game),
        const SizedBox(height: 20),
        _ActionPanel(game: game, task: task),
        const SizedBox(height: 24),
        SavePathsSection(game: game),
        SnapshotsSection(game: game),
        _FilesSection(game: game),
        _InfoSection(game: game),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _remove(context),
            style: TextButton.styleFrom(foregroundColor: EvaporateTheme.danger),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Удалить из библиотеки'),
          ),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final hasFiles =
        game.installDir != null && Directory(game.installDir!).existsSync();

    final choice = await showDialog<_RemoveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${game.title}»?'),
        content: Text(
          hasFiles
              ? 'Снимки сохранений этой игры тоже будут удалены.\n\n'
                    'Файлы игры лежат в:\n${game.installDir}'
              : 'Снимки сохранений этой игры тоже будут удалены.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (hasFiles)
            TextButton(
              onPressed: () => Navigator.pop(context, _RemoveChoice.withFiles),
              style: TextButton.styleFrom(
                foregroundColor: EvaporateTheme.danger,
              ),
              child: const Text('Удалить вместе с файлами'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _RemoveChoice.libraryOnly),
            child: const Text('Удалить из библиотеки'),
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

/// Обложка из Steam, если её удалось найти; иначе — первая буква названия.
///
/// Пока игра качается, поверх обложки идёт полоса прогресса с процентом:
/// состояние загрузки видно сразу, не вчитываясь в панель ниже.
class _Cover extends StatelessWidget {
  const _Cover({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final url = game.coverUrl;
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final showProgress = task != null && task.state != DownloadState.complete;

    return Container(
      width: url == null ? 64 : 132,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: EvaporateTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvaporateTheme.outline),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            Center(
              child: Text(
                game.title.characters.take(1).toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: EvaporateTheme.textSecondary,
                ),
              ),
            )
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              // Обложка — украшение: не грузится, значит её просто нет.
              errorBuilder: (context, error, stack) => const Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: EvaporateTheme.textSecondary,
              ),
            ),
          if (showProgress) _CoverProgress(task: task),
        ],
      ),
    );
  }
}

/// Полоса прогресса поверх обложки.
class _CoverProgress extends StatelessWidget {
  const _CoverProgress({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    // У метаданных и у задачи в очереди процента ещё нет — показываем статус.
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = switch (task) {
      _ when task.isQueued => 'в очереди',
      _ when task.isMetadata => 'метаданные',
      _ when task.state == DownloadState.paused => 'пауза',
      _ when indeterminate => '…',
      _ => '${(task.progress * 100).toStringAsFixed(0)}%',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: indeterminate ? null : task.progress,
                minHeight: 3,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Cover(game: game),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                game.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (game.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  game.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EvaporateTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusChip(status: game.status),
                  const SizedBox(width: 10),
                  if (game.playtime.inMinutes > 0)
                    Text(
                      'Наиграно ${formatDuration(game.playtime)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EvaporateTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Главная кнопка карточки плюс прогресс загрузки.
///
/// Занятость приходит из состояния блока: виджету больше не нужен свой
/// флаг и `try/catch` — ошибки показывает общий слушатель в оболочке.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.game, required this.task});

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
              _ProgressBlock(task: task!),
            ],
            if (game.status == GameStatus.error && game.lastError != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: EvaporateTheme.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.lastError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EvaporateTheme.danger,
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
          label: const Text('Остановить'),
        ),
        const SizedBox(width: 14),
        const Text(
          'Игра запущена',
          style: TextStyle(color: EvaporateTheme.accent, fontSize: 13),
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
          label: Text(paused ? 'Продолжить' : 'Пауза'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _cancelDownload(context),
          icon: const Icon(Icons.close, size: 17),
          label: const Text('Отменить'),
        ),
      ];
    }

    if (game.isInstalled) {
      return [
        FilledButton.icon(
          onPressed: game.canLaunch && !busy
              ? () => library.add(GameLaunchRequested(game))
              : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: const Text('Играть'),
        ),
        const SizedBox(width: 10),
        if (!game.canLaunch)
          const Expanded(
            child: Text(
              'Укажите исполняемый файл ниже, чтобы запускать игру отсюда.',
              style: TextStyle(
                fontSize: 12.5,
                color: EvaporateTheme.textSecondary,
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _openInstallDir(context),
            icon: const Icon(Icons.folder_open, size: 17),
            label: const Text('Папка игры'),
          ),
      ];
    }

    // Не установлена.
    final source = game.source;
    final canDownload =
        source != null && source.kind != GameSourceKind.localFolder;
    return [
      FilledButton.icon(
        onPressed: canDownload
            ? () => downloads.add(DownloadRequested(game: game, source: source))
            : null,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Скачать'),
      ),
      const SizedBox(width: 10),
      OutlinedButton.icon(
        onPressed: () => _pickInstallDir(context),
        icon: const Icon(Icons.folder_outlined, size: 17),
        label: const Text('Указать папку'),
      ),
    ];
  }

  Future<void> _cancelDownload(BuildContext context) async {
    final downloads = context.read<DownloadsBloc>();
    final ok = await confirm(
      context,
      title: 'Отменить загрузку?',
      message: 'Задача будет снята. Уже скачанные файлы останутся на диске.',
      confirmLabel: 'Отменить загрузку',
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

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final indeterminate = task.isMetadata || task.totalBytes == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: indeterminate ? null : task.progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        DefaultTextStyle(
          style: const TextStyle(
            fontSize: 12.5,
            color: EvaporateTheme.textSecondary,
          ),
          child: Row(
            children: [
              Text(
                task.isMetadata
                    ? 'Получаем метаданные торрента…'
                    : '${(task.progress * 100).toStringAsFixed(1)}% · '
                          '${formatBytes(task.completedBytes)} из '
                          '${formatBytes(task.totalBytes)}',
              ),
              const Spacer(),
              if (!task.isMetadata) ...[
                Text(
                  '${formatSpeed(task.downloadSpeed)} · '
                  'осталось ${formatEta(task.etaSeconds)}',
                ),
                const SizedBox(width: 12),
                Text('пиров: ${task.connections}'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Файлы игры',
      icon: Icons.folder_outlined,
      child: Column(
        children: [
          InfoRow(
            label: 'Папка установки',
            value: game.installDir ?? 'не задана',
            monospace: game.installDir != null,
            valueColor: game.installDir == null
                ? EvaporateTheme.textSecondary
                : null,
          ),
          InfoRow(
            label: 'Что запускать',
            value: game.executablePath ?? 'не выбрано',
            monospace: game.executablePath != null,
            valueColor: game.executablePath == null
                ? EvaporateTheme.textSecondary
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickExecutable(context),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Выбрать файл'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: game.installDir == null
                    ? null
                    : () => _autoDetect(context),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Найти автоматически'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickExecutable(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final file = await openFile();
    if (file == null) return;
    library.add(GameUpdated(game.copyWith(executablePath: file.path)));
  }

  Future<void> _autoDetect(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = game.installDir;
    if (dir == null) return;

    final candidates = await ExecutableFinder.scan(dir);
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      showError(context, 'Исполняемых файлов в папке не нашлось.');
      return;
    }

    final chosen = await showDialog<ExecutableCandidate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Что запускать?'),
        content: SizedBox(
          width: 560,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline, size: 18),
                title: Text(
                  candidate.name,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${p.relative(candidate.path, from: dir)} · '
                  '${formatBytes(candidate.sizeBytes)}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onTap: () => Navigator.pop(context, candidate),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    library.add(GameUpdated(game.copyWith(executablePath: chosen.path)));
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final source = game.source;
    return SectionCard(
      title: 'Сведения',
      icon: Icons.info_outline,
      child: Column(
        children: [
          InfoRow(
            label: 'Наиграно',
            value: game.playtime.inMinutes > 0
                ? formatDuration(game.playtime)
                : 'ещё не играли',
          ),
          InfoRow(
            label: 'Последний запуск',
            value: game.lastPlayed == null
                ? '—'
                : formatDateTime(game.lastPlayed!),
          ),
          InfoRow(label: 'Добавлена', value: formatDateTime(game.addedAt)),
          if (game.sizeBytes > 0)
            InfoRow(label: 'Размер', value: formatBytes(game.sizeBytes)),
          if (game.steamAppId != null)
            InfoRow(label: 'Steam', value: 'appid ${game.steamAppId}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (context) {
                final busy = context.select<LibraryBloc, bool>(
                  (bloc) => bloc.state.isBusy(LibraryBloc.steamKey(game.id)),
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
                        ? 'Найти в Steam'
                        : 'Обновить из Steam',
                  ),
                );
              },
            ),
          ),
          if (source != null)
            InfoRow(
              label: 'Источник',
              value: source.kind == GameSourceKind.magnet
                  ? '${source.label}: ${_shorten(source.value)}'
                  : '${source.label}: ${source.value}',
            ),
        ],
      ),
    );
  }

  static String _shorten(String value) =>
      value.length <= 72 ? value : '${value.substring(0, 72)}…';
}
