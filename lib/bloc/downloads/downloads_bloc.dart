import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../models/download_task.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../services/download/download_engine.dart';
import '../../services/download/dtorrent_engine.dart';
import '../../services/launch/executable_finder.dart';
import '../../services/notifications/notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import '../../l10n/app_localizations_ru.dart';
import '../library/library_bloc.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'downloads_event.dart';
part 'downloads_state.dart';

/// Связывает задачи движка с играми библиотеки: переключает статусы,
/// доводит magnet-ссылку до настоящей загрузки и завершает установку.
///
/// Движок — внешний источник событий: его потоки задач, статуса и статистики
/// подаются сюда как обычные события, наравне с нажатиями пользователя.
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  DownloadsBloc({
    required this.paths,
    required this.library,
    required this.settings,
    NotificationService? notifications,
    L Function()? localizations,
  }) : _localizations = localizations ?? _defaultLocalizations,
       notifications = notifications ?? const NoopNotificationService(),
       engine = DtorrentEngine(
         downloadDir: settings.state.installDir,
         stateFile: paths.engineStateFile,
         proxy: settings.state.proxy,
         maxConcurrent: settings.state.maxConcurrent,
       ),
       super(const DownloadsState()) {
    on<DownloadEngineStartRequested>((event, emit) async {
      await applyLimits();
      await engine.start();
    });
    on<DownloadEngineRestartRequested>((event, emit) async {
      await engine.stop();
      await engine.start();
    });
    on<DownloadSettingsApplied>(
      _onSettingsApplied,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<DownloadLimitsRefreshed>(_onLimitsRefreshed);
    library.launcher.runningIds.addListener(_onRunningChanged);
    on<DownloadRequested>(_onDownloadRequested);
    on<DownloadPauseRequested>(_onPauseRequested);
    on<DownloadResumeRequested>(_onResumeRequested);
    on<DownloadCancelRequested>(_onCancelRequested);
    on<DownloadReordered>((event, emit) async {
      await engine.reorder(event.id, event.newIndex);
    });
    on<EngineTasksChanged>(_onTasksChanged);
    on<EngineStatusChanged>((event, emit) {
      emit(state.copyWith(engine: event.status));
    });
    on<EngineStatsChanged>((event, emit) {
      emit(state.copyWith(stats: event.stats));
    });

    engine.tasks.addListener(_pushTasks);
    engine.status.addListener(_pushStatus);
    engine.stats.addListener(_pushStats);
    _settingsSubscription = settings.stream.listen(
      (value) => add(DownloadSettingsApplied(value)),
    );
  }

  final AppPaths paths;
  static L _defaultLocalizations() => LRu();

  final LibraryBloc library;

  /// Откуда брать переводы: у блока нет `BuildContext`, а язык может
  /// смениться на ходу. По умолчанию русский — как и в блоке библиотеки.
  final L Function() _localizations;

  L get _l => _localizations();
  final SettingsBloc settings;
  final DtorrentEngine engine;
  late final StreamSubscription<AppSettings> _settingsSubscription;

  /// Загрузка идёт долго, и окно к её концу обычно свёрнуто — о финале
  /// сообщает система, а не SnackBar в невидимом окне.
  final NotificationService notifications;

  /// Игры, установка которых уже дообрабатывается, — чтобы не запускать
  /// сканирование исполняемых файлов дважды.
  final Set<String> _finalizing = {};
  int _noticeSeq = 0;

  void _pushTasks() => add(EngineTasksChanged(engine.tasks.value));

  void _pushStatus() => add(EngineStatusChanged(engine.status.value));

  void _pushStats() => add(EngineStatsChanged(engine.stats.value));

  Notice _notice(String message, {bool isError = false}) =>
      Notice(message: message, seq: ++_noticeSeq, isError: isError);

  void _notifySystem(AppNotification notification) {
    if (!settings.state.systemNotifications) return;
    unawaited(notifications.show(notification));
  }

  /// Смена прокси перезапускает активные задачи: иначе уже открытые
  /// соединения продолжили бы идти мимо него.
  Future<void> _onSettingsApplied(
    DownloadSettingsApplied event,
    Emitter<DownloadsState> emit,
  ) async {
    final settings = event.settings;
    engine
      ..downloadDir = settings.installDir
      ..maxConcurrent = settings.maxConcurrent
      ..pumpQueue();
    await engine.setProxy(settings.proxy);
    await engine.applyLimits(
      settings.limits,
      playing: library.launcher.runningIds.value.isNotEmpty,
    );
  }

  /// Передаёт движку ограничения скорости с учётом того, играют ли сейчас.
  ///
  /// Про запущенную игру знает библиотека, про скорость — настройки, поэтому
  /// свести их может только тот, кто владеет движком.
  Future<void> applyLimits() => engine.applyLimits(
    settings.state.limits,
    playing: library.launcher.runningIds.value.isNotEmpty,
  );

  /// Игру запустили или закрыли — предел на время игры меняется.
  void _onRunningChanged() => add(const DownloadLimitsRefreshed());

  Future<void> _onLimitsRefreshed(
    DownloadLimitsRefreshed event,
    Emitter<DownloadsState> emit,
  ) => applyLimits();

  // ------------------------------------------------------------ действия

  Future<void> _onDownloadRequested(
    DownloadRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    if (!engine.status.value.isReady) {
      emit(
        state.copyWith(
          notice: _notice(
            _l.noticeEngineNotReady(
              engineStateLabel(_l, engine.status.value.state),
            ),
            isError: true,
          ),
        ),
      );
      return;
    }

    try {
      final dir = settings.state.installDir;
      await Directory(dir).create(recursive: true);

      final String taskId;
      switch (event.source.kind) {
        case GameSourceKind.magnet:
          taskId = await engine.addMagnet(event.source.value, dir: dir);
        case GameSourceKind.torrentFile:
          // Копию .torrent держим у себя: исходный файл могут удалить.
          final stored = await _storeTorrent(event.source.value, event.game.id);
          taskId = await engine.addTorrentFile(stored, dir: dir);
        case GameSourceKind.localFolder:
          emit(
            state.copyWith(
              notice: _notice(_l.noticeLocalFolderNoDownload, isError: true),
            ),
          );
          return;
      }

      library.add(
        GameUpdated(
          event.game.copyWith(
            source: event.source,
            status: GameStatus.downloading,
            downloadTaskId: taskId,
            lastError: null,
          ),
        ),
      );
      emit(state.copyWith(notice: _notice(_l.noticeDownloadStarted)));
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<String> _storeTorrent(String sourcePath, String gameId) async {
    final target = p.join(paths.torrentsDir, '$gameId.torrent');
    await Directory(paths.torrentsDir).create(recursive: true);
    await File(sourcePath).copy(target);
    return target;
  }

  Future<void> _onPauseRequested(
    DownloadPauseRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    final taskId = event.game.downloadTaskId;
    if (taskId == null) return;
    try {
      await engine.pause(taskId);
      library.add(GameUpdated(event.game.copyWith(status: GameStatus.paused)));
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onResumeRequested(
    DownloadResumeRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    final taskId = event.game.downloadTaskId;
    if (taskId == null) return;
    try {
      await engine.resume(taskId);
      library.add(
        GameUpdated(event.game.copyWith(status: GameStatus.downloading)),
      );
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onCancelRequested(
    DownloadCancelRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    final taskId = event.game.downloadTaskId;
    try {
      if (taskId != null) await engine.remove(taskId);
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
    library.add(
      GameUpdated(
        event.game.copyWith(
          status: GameStatus.notInstalled,
          downloadTaskId: null,
        ),
      ),
    );
  }

  // ------------------------------------------------------ синхронизация

  Future<void> _onTasksChanged(
    EngineTasksChanged event,
    Emitter<DownloadsState> emit,
  ) async {
    emit(state.copyWith(tasks: event.tasks));

    for (final game in library.state.games) {
      final taskId = game.downloadTaskId;
      if (taskId == null) continue;
      if (game.status != GameStatus.downloading &&
          game.status != GameStatus.paused) {
        continue;
      }

      var task = state.taskById(taskId);
      if (task == null) {
        // После перезапуска движок поднимает задачи заново, с новыми
        // идентификаторами — связываем задачу с игрой по infohash.
        task = _taskByInfoHash(event.tasks, game.infoHash);
        if (task == null) continue;
        library.add(GameUpdated(game.copyWith(downloadTaskId: task.id)));
        continue;
      }
      if (task.infoHash != null && game.infoHash != task.infoHash) {
        library.add(GameUpdated(game.copyWith(infoHash: task.infoHash)));
      }

      // Magnet сначала качает метаданные, затем порождает основную задачу.
      final next = task.followedBy;
      if (next != null && next != taskId) {
        library.add(GameUpdated(game.copyWith(downloadTaskId: next)));
        continue;
      }

      switch (task.state) {
        case DownloadState.complete:
          if (!task.isMetadata) await _finalize(game, task, emit);
        case DownloadState.error:
          final reason = task.errorMessage ?? _l.noticeDownloadFailedTitle;
          // Опрос движка идёт раз в секунду; уведомляем только на переходе
          // в ошибку, иначе система захлебнётся повторами.
          if (game.status != GameStatus.error) {
            _notifySystem(
              AppNotification(
                title: _l.noticeDownloadFailed,
                body: '«${game.title}»: $reason',
                kind: NotificationKind.downloadFailed,
              ),
            );
          }
          library.add(
            GameUpdated(
              game.copyWith(status: GameStatus.error, lastError: reason),
            ),
          );
        case DownloadState.paused:
          if (game.status != GameStatus.paused) {
            library.add(GameUpdated(game.copyWith(status: GameStatus.paused)));
          }
        case DownloadState.active:
        case DownloadState.waiting:
          if (game.status != GameStatus.downloading) {
            library.add(
              GameUpdated(game.copyWith(status: GameStatus.downloading)),
            );
          }
        case DownloadState.removed:
          library.add(
            GameUpdated(
              game.copyWith(
                status: GameStatus.notInstalled,
                downloadTaskId: null,
              ),
            ),
          );
      }
    }
  }

  static DownloadTask? _taskByInfoHash(
    List<DownloadTask> tasks,
    String? infoHash,
  ) {
    if (infoHash == null || infoHash.isEmpty) return null;
    for (final task in tasks) {
      if (task.infoHash == infoHash) return task;
    }
    return null;
  }

  /// Загрузка закончилась: определяем папку игры и пытаемся угадать,
  /// что именно запускать.
  Future<void> _finalize(
    Game game,
    DownloadTask task,
    Emitter<DownloadsState> emit,
  ) async {
    if (!_finalizing.add(game.id)) return;
    try {
      final installDir = deriveInstallDir(task) ?? settings.state.installDir;
      var updated = game.copyWith(
        status: GameStatus.installed,
        installDir: installDir,
        downloadTaskId: null,
        sizeBytes: task.totalBytes,
        lastError: null,
      );

      if (updated.executablePath == null) {
        final candidates = await ExecutableFinder.scan(installDir);
        if (candidates.isNotEmpty) {
          updated = updated.copyWith(executablePath: candidates.first.path);
        }
      }
      // Хеши кусков сверяются при скачивании, но пропавший или обрезанный
      // файл протокол уже не заметит — проверяем перед тем, как объявить
      // игру готовой.
      final report = await engine.verify(task.id);
      if (!report.isValid) {
        library.add(
          GameUpdated(
            game.copyWith(
              status: GameStatus.error,
              installDir: installDir,
              downloadTaskId: null,
              lastError: _l.noticeDownloadIncompleteBody(report.describe(_l)),
            ),
          ),
        );
        await library.persist();
        emit(
          state.copyWith(
            notice: _notice(
              _l.noticeDownloadIncomplete(game.title, report.describe(_l)),
              isError: true,
            ),
          ),
        );
        _notifySystem(
          AppNotification(
            title: _l.noticeDownloadIncompleteShort,
            body: '«${game.title}»: ${report.describe(_l)}',
            kind: NotificationKind.downloadFailed,
          ),
        );
        return;
      }

      library.add(GameUpdated(updated));
      await library.persist();

      // Имя раздачи известно только сейчас — по нему и ищем игру в Steam.
      if (updated.steamAppId == null) {
        library.add(SteamLookupRequested(updated, query: task.name));
      }

      emit(
        state.copyWith(notice: _notice(_l.noticeGameDownloaded(game.title))),
      );
      _notifySystem(
        AppNotification(
          title: _l.noticeDownloadFinished,
          body: _l.noticeGameReady(game.title),
          kind: NotificationKind.downloadFinished,
        ),
      );
    } finally {
      _finalizing.remove(game.id);
    }
  }

  /// Торрент с корневой папкой должен дать именно эту папку, а не общий
  /// каталог загрузок — иначе «удалить игру» снесёт лишнее.
  ///
  /// Открыто для тестов: ошибка здесь стоит чужих файлов, а проверить её
  /// можно на одной задаче, без движка и без диска.
  @visibleForTesting
  static String? deriveInstallDir(DownloadTask task) {
    if (task.files.isEmpty) return task.dir;
    final dir = task.dir;
    if (dir == null) return p.dirname(task.files.first);

    final relative = p.relative(task.files.first, from: dir);
    final segments = p.split(relative);
    if (segments.length > 1) {
      final root = p.join(dir, segments.first);
      if (task.files.every((f) => p.isWithin(root, f))) return root;
    }
    return dir;
  }

  @override
  Future<void> close() async {
    engine.tasks.removeListener(_pushTasks);
    engine.status.removeListener(_pushStatus);
    engine.stats.removeListener(_pushStats);
    library.launcher.runningIds.removeListener(_onRunningChanged);
    await _settingsSubscription.cancel();
    engine.dispose();
    return super.close();
  }
}
