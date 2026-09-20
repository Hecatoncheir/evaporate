import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../l10n/labels.dart';
import '../../models/app_settings.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../services/download/download_engine.dart';
import '../../services/download/dtorrent_engine.dart';
import '../../services/download/torrent_export.dart';
import '../../services/launch/executable_finder.dart';
import '../../services/notifications/notification_service.dart';
import '../bloc_common.dart';
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
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState>
    with NoticeBloc<DownloadsState> {
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
         torrentsDir: paths.torrentsDir,
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
    on<TorrentExportRequested>(_onTorrentExport);
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
    // Раздача, брошенная в окно, ставится в очередь здесь: библиотека
    // заводит игру, а что делать с её источником — дело загрузок.
    _dropSubscription = library.gameDrops.listen(_onGamesDropped);
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
  late final StreamSubscription<DroppedGames> _dropSubscription;

  /// Загрузка идёт долго, и окно к её концу обычно свёрнуто — о финале
  /// сообщает система, а не SnackBar в невидимом окне.
  final NotificationService notifications;

  /// Игры, установка которых уже дообрабатывается, — чтобы не запускать
  /// сканирование исполняемых файлов дважды.
  final Set<String> _finalizing = {};

  void _pushTasks() => add(EngineTasksChanged(engine.tasks.value));

  void _pushStatus() => add(EngineStatusChanged(engine.status.value));

  void _pushStats() => add(EngineStatsChanged(engine.stats.value));

  @override
  String get logTag => 'загрузки';

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

  /// Ставит в очередь то из брошенного, что качают.
  ///
  /// Папка уже лежит на диске — качать нечего; отказ движка объяснит сам
  /// [DownloadRequested], и молчания, как прежде, не будет.
  void _onGamesDropped(DroppedGames dropped) {
    for (final game in dropped.games) {
      final source = game.source;
      if (source == null || source.kind == GameSourceKind.localFolder) {
        continue;
      }
      add(DownloadRequested(game: game, source: source));
    }
  }

  Future<void> _onDownloadRequested(
    DownloadRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    if (!engine.status.value.isReady) {
      emit(
        state.copyWith(
          notice: notice(
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
              notice: notice(_l.noticeLocalFolderNoDownload, isError: true),
            ),
          );
          return;
      }

      library.add(GameDownloadStarted(event.game.id, event.source, taskId));
      emit(state.copyWith(notice: notice(_l.noticeDownloadStarted)));
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
  }

  Future<String> _storeTorrent(String sourcePath, String gameId) async {
    final target = p.join(paths.torrentsDir, '$gameId.torrent');
    await Directory(paths.torrentsDir).create(recursive: true);
    await File(sourcePath).copy(target);
    return target;
  }

  /// Где искать `.torrent` игры. Собственного состояния у поиска нет,
  /// поэтому он собирается на каждый запрос.
  TorrentExport get torrents => TorrentExport(
    torrentsDir: paths.torrentsDir,
    enginePath: engine.torrentPathFor,
  );

  /// Отдаёт файл раздачи наружу: в другой клиент, на другое устройство или
  /// просто в архив. Раздача, которую скачали, остаётся раздачей — унести её
  /// с собой человек вправе, а magnet-ссылка без метаданных этого не даёт.
  Future<void> _onTorrentExport(
    TorrentExportRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      final source = await torrents.locate(event.game);
      if (source == null) {
        emit(
          state.copyWith(
            notice: notice(_l.noticeTorrentUnavailable, isError: true),
          ),
        );
        return;
      }
      await File(source).copy(event.destination);
      emit(state.copyWith(notice: notice(_l.noticeSavedTo(event.destination))));
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onPauseRequested(
    DownloadPauseRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    final taskId = event.game.downloadTaskId;
    if (taskId == null) return;
    try {
      await engine.pause(taskId);
      library.add(GameStatusChanged(event.game.id, GameStatus.paused));
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
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
      library.add(GameStatusChanged(event.game.id, GameStatus.downloading));
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onCancelRequested(
    DownloadCancelRequested event,
    Emitter<DownloadsState> emit,
  ) async {
    final taskId = event.game.downloadTaskId;
    // Задачу надо запомнить до снятия: после `remove` движок о ней забудет,
    // а именно она знает, где лежит скачанное.
    final task = taskId == null ? null : engine.taskById(taskId);
    try {
      if (taskId != null) await engine.remove(taskId);
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
    if (event.deleteFiles && task != null) {
      try {
        await deleteDownloaded(task, root: settings.state.installDir);
      } on Object catch (error) {
        emit(state.copyWith(notice: notice(error.toString(), isError: true)));
      }
    }
    library.add(GameDownloadDropped(event.game.id));
  }

  // ------------------------------------------------------ синхронизация

  /// Сводит состояние игр с тем, что сообщил движок.
  ///
  /// Событие приходит раз в секунду и сразу обо всех задачах, поэтому здесь
  /// только развилка: что делать с одной игрой — в методах ниже.
  Future<void> _onTasksChanged(
    EngineTasksChanged event,
    Emitter<DownloadsState> emit,
  ) async {
    emit(state.copyWith(tasks: event.tasks));

    for (final game in library.state.games) {
      if (!_isBeingDownloaded(game)) continue;

      final task = state.taskById(game.downloadTaskId!);
      if (task == null) {
        _relinkByInfoHash(game, event.tasks);
        continue;
      }
      _syncInfoHash(game, task);
      await _applyTaskState(game, task, emit);
    }
  }

  /// Игра, за загрузкой которой мы следим.
  static bool _isBeingDownloaded(Game game) =>
      game.downloadTaskId != null &&
      (game.status == GameStatus.downloading ||
          game.status == GameStatus.paused);

  /// Заново связывает игру с задачей движка.
  ///
  /// После перезапуска движок поднимает задачи с новыми идентификаторами,
  /// и единственное, чем игру можно узнать, — её infohash.
  void _relinkByInfoHash(Game game, List<DownloadTask> tasks) {
    final task = _taskByInfoHash(tasks, game.infoHash);
    if (task == null) return;
    library.add(GameDownloadLinked(game.id, taskId: task.id));
  }

  /// Запоминает infohash, который движок узнал уже в работе: по
  /// magnet-ссылке он приходит вместе с метаданными, а не сразу.
  void _syncInfoHash(Game game, DownloadTask task) {
    if (task.infoHash == null || game.infoHash == task.infoHash) return;
    library.add(GameDownloadLinked(game.id, infoHash: task.infoHash));
  }

  /// Переносит состояние задачи движка в состояние игры.
  Future<void> _applyTaskState(
    Game game,
    DownloadTask task,
    Emitter<DownloadsState> emit,
  ) async {
    switch (task.state) {
      case DownloadState.complete:
        if (!task.isMetadata) await _finalize(game, task, emit);
      case DownloadState.error:
        _markFailed(game, task);
      case DownloadState.paused:
        _setStatus(game, GameStatus.paused);
      case DownloadState.active:
      case DownloadState.waiting:
        _setStatus(game, GameStatus.downloading);
    }
  }

  /// Ставит игре состояние, если оно и правда сменилось: движок
  /// опрашивается раз в секунду, и лишнее событие тут — лишняя запись.
  void _setStatus(Game game, GameStatus status) {
    if (game.status == status) return;
    library.add(GameStatusChanged(game.id, status));
  }

  /// Отмечает сорвавшуюся загрузку и один раз сообщает о ней системой.
  ///
  /// Опрос движка идёт раз в секунду; уведомляем только на переходе
  /// в ошибку, иначе система захлебнётся повторами.
  void _markFailed(Game game, DownloadTask task) {
    final reason = task.errorMessage ?? _l.noticeDownloadFailedTitle;
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
      GameStatusChanged(game.id, GameStatus.error, lastError: reason),
    );
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
      String? executable;
      if (game.executablePath == null) {
        final candidates = await ExecutableFinder.scan(installDir);
        if (candidates.isNotEmpty) executable = candidates.first.path;
      }
      // Хеши кусков сверяются при скачивании, но пропавший или обрезанный
      // файл протокол уже не заметит — проверяем перед тем, как объявить
      // игру готовой.
      final report = await engine.verify(task.id);
      if (!report.isValid) {
        library.add(
          GameDownloadRejected(
            game.id,
            installDir: installDir,
            reason: _l.noticeDownloadIncompleteBody(report.describe(_l)),
          ),
        );
        await library.persist();
        emit(
          state.copyWith(
            notice: notice(
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

      library.add(
        GameDownloadFinished(
          game.id,
          installDir: installDir,
          sizeBytes: task.totalBytes,
          executablePath: executable,
          metadataQuery: task.name,
        ),
      );
      await library.persist();

      emit(state.copyWith(notice: notice(_l.noticeGameDownloaded(game.title))));
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

  /// Убирает с диска то, что задача успела скачать.
  ///
  /// **Папку сносим только внутри корня загрузок и только не сам корень.**
  /// У раздачи из одного файла, лежащего в корне, [deriveInstallDir]
  /// возвращает этот самый корень — снести его значило бы унести всю
  /// библиотеку игр заодно с этой. Поэтому такой случай разбирается
  /// пофайлово: убираем ровно то, что задача назвала своим, и ничего
  /// сверх.
  /// Открыто и статично ради проверки: ошибка здесь стоит чужих файлов, а
  /// корень передаётся снаружи — значит, тесту не нужны ни движок, ни
  /// настройки, только временная папка.
  @visibleForTesting
  static Future<void> deleteDownloaded(
    DownloadTask task, {
    required String root,
  }) async {
    final dir = deriveInstallDir(task);
    // `isWithin` на равных путях даёт false — это здесь и нужно.
    if (dir != null && p.isWithin(root, dir)) {
      final directory = Directory(dir);
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    }
    for (final path in task.files) {
      if (!p.isWithin(root, path)) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
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
    await _dropSubscription.cancel();
    // Гасим задачи именно дожидаясь: `dispose` бросает их на полпути, а
    // движок ведёт свой файл состояния — оборванная задача теряет то,
    // что успела скачать сверх последней записи.
    await engine.stop();
    engine.dispose();
    return super.close();
  }
}
