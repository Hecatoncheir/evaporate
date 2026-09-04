import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../core/format.dart';
import '../../core/json_store.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/bulk_report.dart';
import '../../models/catalog_progress.dart';
import '../../models/save_snapshot.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/metadata/steam_catalog.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/saves/ludusavi_catalog.dart';
import '../../services/saves/save_activity_watch.dart';
import '../../services/saves/save_path_finder.dart';
import '../../services/saves/save_path_globs.dart';
import '../../services/saves/bulk_transfer.dart';
import '../../services/saves/save_manager.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'library_event.dart';
part 'library_state.dart';

/// Библиотека игр и их сохранений — единственный источник правды для UI.
///
/// Ошибки наружу не выбрасываются: обработчики кладут результат в [Notice],
/// а экраны показывают его через `BlocListener`.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({
    required AppPaths paths,
    required this.settings,
    JsonStore? store,
    SaveManager? saveManager,
    GameLauncher? launcher,
    NotificationService? notifications,
    SteamCatalog? steam,
    LudusaviCatalog? savePaths,
    L Function()? localizations,
    List<SaveRoot> Function()? saveRoots,
    this.automaticMetadata = true,
  }) : steam = steam ?? SteamCatalog(proxy: () => settings.state.proxy),
       savePaths =
           savePaths ??
           LudusaviCatalog(
             cacheFile: paths.savePathsCacheFile,
             proxy: () => settings.state.proxy,
           ),
       _localizations = localizations ?? _defaultLocalizations,
       notifications = notifications ?? const NoopNotificationService(),
       _store = store ?? JsonStore(paths.libraryFile),
       _coversDir = paths.coversDir,
       _saves = saveManager ?? SaveManager(paths: paths),
       _launcher = launcher ?? GameLauncher(),
       _saveRoots = saveRoots ?? SavePathFinder.roots,
       super(const LibraryState()) {
    // Собирается здесь, а не в списке инициализации: там на _saves,
    // от которого он зависит, ссылаться ещё нельзя.
    _bulk = BulkTransfer(saves: _saves, localizations: _localizations);
    on<LibraryLoadRequested>(_onLoadRequested);
    on<GameAdded>(_onGameAdded);
    on<GameUpdated>(_onGameUpdated);
    on<GameRemoved>(_onGameRemoved);
    on<GameLaunchRequested>(_onLaunchRequested);
    on<GameStopRequested>(_onStopRequested);
    on<GameExited>(_onGameExited);
    on<RunningGamesChanged>(_onRunningGamesChanged);
    on<SnapshotRequested>(_onSnapshotRequested);
    on<SnapshotRestoreRequested>(_onRestoreRequested);
    on<SnapshotImportRequested>(_onImportRequested);
    on<SnapshotExportRequested>(_onExportRequested);
    on<SnapshotDeleted>(_onSnapshotDeleted);
    on<SteamLookupRequested>(_onSteamLookup);
    on<SavePathsLookupRequested>(_onSavePathsLookup);
    on<SavePathsProgressChanged>(_onSavePathsProgress);
    on<SaveHintsRequested>(_onSaveHintsRequested);
    on<SaveHintsAccepted>(_onSaveHintsAccepted);
    on<SaveHintsDismissed>(_onSaveHintsDismissed);
    // this нужен явно: без него имя разрешается в параметр конструктора.
    this.savePaths.onProgress = (value) {
      if (!_closing) add(SavePathsProgressChanged(value));
    };
    on<BulkExportRequested>(_onBulkExport);
    on<BulkImportRequested>(_onBulkImport);
    on<SyncFolderScanRequested>(_onSyncScanRequested);
    on<SyncPackageApplied>(_onSyncPackageApplied);

    _launcher.runningIds.addListener(_pushRunningGames);
  }

  final SettingsBloc settings;

  /// Отключается в изолированных тестах без сетевых сервисов.
  final bool automaticMetadata;
  final String _coversDir;

  /// Откуда брать переводы для уведомлений.
  ///
  /// У блока нет `BuildContext`, поэтому локализация приходит извне функцией:
  /// язык может смениться на ходу, и держать один объект нельзя. По умолчанию
  /// русский — тесты проверяют текст уведомлений и языка не задают.
  final L Function() _localizations;

  L get _l => _localizations();

  /// Автоснимок после выхода из игры молчалив по замыслу, но его провал
  /// пользователь обязан заметить — иначе узнает, только потеряв прогресс.
  final NotificationService notifications;

  /// Каталог Steam: по имени раздачи находит название, описание и обложку.
  final SteamCatalog steam;

  /// Открытая база путей сохранений — та часть работы, которую иначе
  /// пришлось бы делать руками для каждой игры.
  final LudusaviCatalog savePaths;

  /// Где смотреть следы работы игры. Подменяется в тестах: настоящие
  /// «Документы» и `AppData` там обходить незачем и небезопасно.
  final List<SaveRoot> Function() _saveRoots;

  final JsonStore _store;
  final SaveManager _saves;

  /// Перенос сохранений всей библиотеки: единственная операция, идущая по
  /// всем играм разом, и единственная со своим счётом исходов.
  late final BulkTransfer _bulk;
  final GameLauncher _launcher;

  Timer? _persistTimer;
  bool _closing = false;
  int _noticeSeq = 0;

  /// Чтение манифеста чужого `.evsave` состояния не меняет, поэтому диалог
  /// подтверждения обращается к менеджеру напрямую.
  SaveManager get saveManager => _saves;

  GameLauncher get launcher => _launcher;

  static L _defaultLocalizations() => LRu();

  static String snapshotKey(String gameId) => 'snapshot:$gameId';

  static String steamKey(String gameId) => 'steam:$gameId';

  static String savePathsKey(String gameId) => 'paths:$gameId';

  /// Ключ занятости для операций над всей библиотекой сразу.
  static const bulkKey = 'bulk';

  /// Допуск на расхождение часов при массовой загрузке. Само правило живёт
  /// в [BulkTransfer]; здесь — чтобы на него можно было сослаться, зная
  /// только блок.
  static const conflictTolerance = BulkTransfer.defaultConflictTolerance;

  static String launchKey(String gameId) => 'launch:$gameId';

  void _pushRunningGames() =>
      add(RunningGamesChanged(_launcher.runningIds.value));

  Notice _notice(String message, {bool isError = false}) =>
      Notice(message: message, seq: ++_noticeSeq, isError: isError);

  void _notifySystem(AppNotification notification) {
    if (!settings.state.systemNotifications) return;
    unawaited(notifications.show(notification));
  }

  Set<String> _withBusy(String key, bool value) {
    final next = Set<String>.from(state.busy);
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return next;
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), persist);
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    await _store.write({
      'version': 1,
      'games': state.games.map((g) => g.toJson()).toList(),
      'snapshots': state.snapshots.map(
        (key, value) => MapEntry(key, value.map((s) => s.toJson()).toList()),
      ),
    });
  }

  // ---------------------------------------------------------------- игры

  Future<void> _onLoadRequested(
    LibraryLoadRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final json = await _store.readAs((json) {
      if ((json['version'] ?? 1) != 1 ||
          (json['games'] != null && json['games'] is! List) ||
          (json['snapshots'] != null && json['snapshots'] is! Map)) {
        throw const FormatException('Invalid library schema');
      }
      return json;
    });
    if (json == null) {
      emit(state.copyWith(loaded: true, notice: _storageRecoveryNotice()));
      return;
    }
    var damaged = false;
    final games = <Game>[];
    for (final entry in json['games'] as List<dynamic>? ?? []) {
      try {
        games.add(Game.fromJson(entry as Map<String, dynamic>));
      } on Object {
        damaged = true;
      }
    }
    final snapshots = <String, List<SaveSnapshot>>{};
    (json['snapshots'] as Map<String, dynamic>? ?? {}).forEach((gameId, value) {
      if (value is! List) {
        damaged = true;
        return;
      }
      final recovered = <SaveSnapshot>[];
      for (final entry in value) {
        try {
          recovered.add(SaveSnapshot.fromJson(entry as Map<String, dynamic>));
        } on Object {
          damaged = true;
        }
      }
      snapshots[gameId] = recovered;
    });
    if (damaged) await _store.quarantine();
    emit(
      state.copyWith(
        games: games,
        snapshots: snapshots,
        loaded: true,
        notice: _storageRecoveryNotice(),
      ),
    );
    for (final game in games) {
      _queueMetadata(game);
    }
  }

  Notice? _storageRecoveryNotice() {
    final path = _store.recoveryPath;
    return path == null
        ? state.notice
        : _notice(_l.noticeStorageRecovered(path), isError: true);
  }

  void _onGameAdded(GameAdded event, Emitter<LibraryState> emit) {
    final title = event.title.trim();
    final game = Game(
      id: event.id,
      title: title.isEmpty ? _l.untitled : title,
      addedAt: DateTime.now(),
      source: event.source,
      installDir: event.installDir,
      executablePath: event.executablePath,
      status: event.status,
      saveProfile: SaveProfile(
        autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
      ),
    );
    emit(state.copyWith(games: [...state.games, game]));
    _schedulePersist();
    _queueMetadata(game);
  }

  void _onGameUpdated(GameUpdated event, Emitter<LibraryState> emit) {
    final index = state.games.indexWhere((g) => g.id == event.game.id);
    if (index == -1) return;
    final previous = state.games[index];
    // Событие загрузки/редактора могло захватить игру до ответа каталога.
    final updated = event.game.copyWith(
      steamLookupAttempted:
          previous.steamLookupAttempted || event.game.steamLookupAttempted,
      savePathsLookupAttempted:
          previous.savePathsLookupAttempted ||
          event.game.savePathsLookupAttempted,
      steamAppId: event.game.steamAppId ?? previous.steamAppId,
      coverUrl: event.game.coverUrl ?? previous.coverUrl,
      coverPath: event.game.coverPath ?? previous.coverPath,
      description: event.game.description ?? previous.description,
      ludusaviTemplates: event.game.ludusaviTemplates.isEmpty
          ? previous.ludusaviTemplates
          : event.game.ludusaviTemplates,
      ludusaviResolvedPaths: {
        ...previous.ludusaviResolvedPaths,
        ...event.game.ludusaviResolvedPaths,
      }.toList(),
      saveProfile:
          previous.savePathsLookupAttempted &&
              !event.game.savePathsLookupAttempted
          ? event.game.saveProfile.copyWith(
              rules: [
                ...event.game.saveProfile.rules,
                for (final rule in previous.saveProfile.rules)
                  if (previous.ludusaviResolvedPaths.contains(rule.template) &&
                      !event.game.saveProfile.rules.any(
                        (r) => r.template == rule.template,
                      ))
                    rule,
              ],
            )
          : event.game.saveProfile,
    );
    final games = [...state.games];
    games[index] = updated;
    emit(state.copyWith(games: games));
    _schedulePersist();
    _queueMetadata(updated, query: event.metadataQuery);
  }

  void _queueMetadata(Game game, {String? query}) {
    if (_closing ||
        !automaticMetadata ||
        !game.isInstalled ||
        game.installDir == null) {
      return;
    }
    if (game.steamAppId == null && !game.steamLookupAttempted) {
      add(SteamLookupRequested(game, query: query, automatic: true));
    } else if (game.steamAppId != null && !game.savePathsLookupAttempted) {
      add(SavePathsLookupRequested(game, automatic: true));
    }
  }

  void _replaceGame(Game game, Emitter<LibraryState> emit) {
    final index = state.games.indexWhere((item) => item.id == game.id);
    if (index == -1) return;
    final games = [...state.games];
    games[index] = game;
    emit(state.copyWith(games: games));
  }

  Future<void> _onGameRemoved(
    GameRemoved event,
    Emitter<LibraryState> emit,
  ) async {
    final game = state.gameById(event.game.id);
    if (game == null) return;
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    final removed = snapshots.remove(game.id) ?? const <SaveSnapshot>[];
    emit(
      state.copyWith(
        games: state.games.where((g) => g.id != game.id).toList(),
        snapshots: snapshots,
      ),
    );
    await persist();

    final cover = game.coverPath;
    if (cover != null && p.isWithin(_coversDir, cover)) {
      final file = File(cover);
      if (await file.exists()) await file.delete();
    }
    for (final snapshot in removed) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object {
        // Файл мог быть уже удалён вручную.
      }
    }
    if (event.deleteFiles && game.installDir != null) {
      final dir = Directory(game.installDir!);
      // Не удаляем что-то за пределами папки установки — страховка от опечаток.
      if (await dir.exists() &&
          p.isWithin(settings.state.installDir, dir.path)) {
        await dir.delete(recursive: true);
      }
    }
  }

  // ------------------------------------------------------------- запуск

  Future<void> _onLaunchRequested(
    GameLaunchRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final key = launchKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      await _launcher.launch(
        game,
        onExit: (exited, played, exitCode) => add(
          GameExited(gameId: exited.id, played: played, exitCode: exitCode),
        ),
      );
      final index = state.games.indexWhere((g) => g.id == game.id);
      if (index != -1) {
        final games = [...state.games];
        games[index] = game.copyWith(
          status: GameStatus.running,
          lastError: null,
        );
        emit(state.copyWith(games: games, busy: _withBusy(key, false)));
        _schedulePersist();
        return;
      }
      emit(state.copyWith(busy: _withBusy(key, false)));
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onStopRequested(
    GameStopRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await _launcher.terminate(event.game.id);
  }

  void _onGameExited(GameExited event, Emitter<LibraryState> emit) {
    final current = state.gameById(event.gameId);
    if (current == null) return;

    // Меньше минуты — обычно неудачный запуск, не засоряем статистику.
    final counted = event.played.inSeconds >= 60 ? event.played : Duration.zero;
    final updated = current.copyWith(
      status: GameStatus.installed,
      playtime: current.playtime + counted,
      lastPlayed: DateTime.now(),
    );
    final games = [...state.games];
    games[games.indexWhere((g) => g.id == event.gameId)] = updated;
    emit(state.copyWith(games: games));
    _schedulePersist();

    if (updated.saveProfile.autoSnapshotOnExit &&
        (updated.saveProfile.isConfigured ||
            updated.ludusaviTemplates.isNotEmpty)) {
      add(SnapshotRequested(updated, origin: SnapshotOrigin.autoOnExit));
    }

    // Слишком короткий сеанс — обычно неудачный запуск: игра не успела
    // ничего записать, а обход папок стоит секунд.
    if (event.played >= _shortestWatchedSession) {
      add(
        SaveHintsRequested(
          game: updated,
          since: DateTime.now().subtract(event.played),
        ),
      );
    }
  }

  /// Короче этого запуск не считаем игрой: сейвы за такое время не заводят.
  static const _shortestWatchedSession = Duration(seconds: 30);

  void _onRunningGamesChanged(
    RunningGamesChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(runningIds: event.ids));
  }

  // -------------------------------------------------------------- сейвы

  /// Маски раскрываются локально: папка профиля могла появиться только
  /// после первого запуска. Сохранённый манифест повторно не запрашиваем.
  Future<Game?> _resolveStoredPaths(
    Game game,
    Emitter<LibraryState> emit,
  ) async {
    final expanded = <String>{};
    for (final template in game.ludusaviTemplates) {
      expanded.addAll(
        await SavePathGlobs.expand(template, gameDir: game.installDir),
      );
    }
    final current = state.gameById(game.id);
    if (current == null || current.addedAt != game.addedAt) return null;
    final existing = current.saveProfile.rules
        .map((rule) => rule.template)
        .toSet();
    final added = SavePathRule.withoutNested(expanded.toList())
        .where(
          (path) =>
              !existing.contains(path) &&
              !current.ludusaviResolvedPaths.contains(path),
        )
        .toList();
    if (added.isEmpty) return current;
    final labels = SavePathRule.labelsFor([...existing, ...added]);
    final updated = current.copyWith(
      ludusaviResolvedPaths: {
        ...current.ludusaviResolvedPaths,
        ...expanded,
      }.toList(),
      saveProfile: current.saveProfile.copyWith(
        rules: [
          ...current.saveProfile.rules,
          for (var i = 0; i < added.length; i++)
            SavePathRule(
              id: const Uuid().v4(),
              label: labels[existing.length + i],
              template: added[i],
            ),
        ],
      ),
    );
    _replaceGame(updated, emit);
    await persist();
    return updated;
  }

  Future<void> _onSnapshotRequested(
    SnapshotRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final initial = state.gameById(event.game.id);
    if (initial == null) return;
    var game = initial;
    final silent = event.origin == SnapshotOrigin.autoOnExit;
    final key = snapshotKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));

    try {
      final resolved = await _resolveStoredPaths(game, emit);
      if (resolved == null) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        return;
      }
      game = resolved;
      final snapshot = await _saves.createSnapshot(
        game,
        origin: event.origin,
        note: event.note,
      );

      if (settings.state.autoExportToSync &&
          settings.state.syncFolder != null) {
        try {
          await _exportToSyncFolder(snapshot);
        } on Object {
          // Папка синхронизации могла отвалиться — снимок уже сохранён локально.
        }
      }

      emit(
        state.copyWith(
          snapshots: _withSnapshot(snapshot),
          busy: _withBusy(key, false),
          notice: silent
              ? state.notice
              : _notice(
                  _l.noticeSnapshotReady(
                    snapshot.fileCount,
                    _formatSize(snapshot.sizeBytes),
                  ),
                ),
        ),
      );
      await _prune(game, emit);
      await persist();
    } on SaveException catch (error) {
      if (silent) {
        // Молчаливый автоснимок провалился — единственный способ сообщить.
        _notifySystem(
          AppNotification(
            title: _l.noticeSnapshotFailed,
            body: _l.noticeSaveFailedBody(game.title, error.message),
            kind: NotificationKind.saveFailed,
          ),
        );
      }
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: silent ? state.notice : _notice(error.message, isError: true),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Map<String, List<SaveSnapshot>> _withSnapshot(SaveSnapshot snapshot) {
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[snapshot.gameId] = [snapshot, ...?snapshots[snapshot.gameId]];
    return snapshots;
  }

  Future<void> _prune(Game game, Emitter<LibraryState> emit) async {
    final keep = game.saveProfile.keepSnapshots;
    if (keep <= 0) return;
    final list = state.snapshots[game.id];
    if (list == null || list.length <= keep) return;

    final excess = list.sublist(keep);
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[game.id] = list.sublist(0, keep);
    emit(state.copyWith(snapshots: snapshots));

    for (final snapshot in excess) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object {
        // Пропускаем: ротация не критична.
      }
    }
  }

  Future<void> _onRestoreRequested(
    SnapshotRestoreRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: event.snapshot,
        backupCurrent: event.backupCurrent,
        wipeTarget: event.wipeTarget,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice(
                  _l.noticeRestoredFiles(
                    report.filesWritten,
                    _formatSize(report.bytesWritten),
                  ),
                )
              : _notice(
                  _l.noticeUnresolvedPaths(report.unresolved.join(', ')),
                  isError: true,
                ),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onImportRequested(
    SnapshotImportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(
        state.copyWith(
          snapshots: _withSnapshot(snapshot),
          busy: _withBusy(key, false),
          notice: _notice(_l.noticeSnapshotImported),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onExportRequested(
    SnapshotExportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    try {
      await _saves.exportSnapshot(event.snapshot, event.destination);
      emit(
        state.copyWith(notice: _notice(_l.noticeSavedTo(event.destination))),
      );
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onSnapshotDeleted(
    SnapshotDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    final list = state.snapshots[event.snapshot.gameId];
    if (list != null) {
      final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
      snapshots[event.snapshot.gameId] = list
          .where((s) => s.id != event.snapshot.id)
          .toList();
      emit(state.copyWith(snapshots: snapshots));
    }
    try {
      await _saves.deleteSnapshot(event.snapshot);
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
    await persist();
  }

  Future<File> _exportToSyncFolder(SaveSnapshot snapshot) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      throw SaveException(_l.noticeSyncFolderNotSet);
    }
    final name =
        '${safeFileName('${snapshot.gameTitle} - ${snapshot.deviceName}')}'
        '${SaveSnapshot.fileExtension}';
    return _saves.exportSnapshot(snapshot, p.join(folder, name));
  }

  /// Ищет игру в Steam и дополняет карточку. Название не трогаем: имя
  /// в библиотеке пользователь мог задать сам.
  Future<void> _onSteamLookup(
    SteamLookupRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = steamKey(event.game.id);
    final game = state.gameById(event.game.id);
    if (game == null ||
        state.isBusy(key) ||
        (event.automatic &&
            (game.steamLookupAttempted || game.steamAppId != null))) {
      return;
    }
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      _replaceGame(game.copyWith(steamLookupAttempted: true), emit);
      // Маркер записан до сети: даже аварийный выход не вызывает повтор.
      await persist();
      final match = await steam.bestMatch(event.query ?? game.title);
      if (_closing) return;
      if (match == null) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: event.automatic
                ? state.notice
                : _notice(_l.noticeSteamNothingFound),
          ),
        );
        return;
      }

      final coverBytes = await steam.coverBytes(match);
      if (_closing) return;
      var current = state.gameById(game.id);
      if (current == null || current.addedAt != game.addedAt) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        return;
      }

      var coverPath = current.coverPath;
      final previousCover = coverPath;
      if (coverBytes != null &&
          (coverPath == null || p.isWithin(_coversDir, coverPath))) {
        final file = File(
          p.join(
            _coversDir,
            '${safeFileName(game.id)}-${DateTime.now().microsecondsSinceEpoch}-steam.jpg',
          ),
        );
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(coverBytes, flush: true);
          coverPath = file.path;
        } on FileSystemException {
          // Ошибка кэша обложки не отменяет ID, описание и поиск сейвов.
        }
        current = state.gameById(game.id);
        if (current == null || current.addedAt != game.addedAt) {
          if (await file.exists()) await file.delete();
          emit(state.copyWith(busy: _withBusy(key, false)));
          return;
        }
      }

      final index = state.games.indexWhere((g) => g.id == game.id);
      final games = [...state.games];
      games[index] = current.copyWith(
        steamAppId: match.appId,
        coverUrl: match.headerImage,
        description: match.description,
        coverPath: coverPath,
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: event.automatic
              ? state.notice
              : _notice(_l.noticeSteamFound(match.name)),
        ),
      );
      await persist();
      if (previousCover != null &&
          previousCover != coverPath &&
          p.isWithin(_coversDir, previousCover)) {
        try {
          final old = File(previousCover);
          if (await old.exists()) await old.delete();
        } on FileSystemException {
          // Неудачная уборка старой обложки не отменяет новые метаданные.
        }
      }
      final updated = state.gameById(game.id);
      if (!_closing &&
          updated != null &&
          (!event.automatic || !updated.savePathsLookupAttempted)) {
        add(SavePathsLookupRequested(updated, automatic: event.automatic));
      }
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Подбирает папки сохранений по базе. Уже заданные правила не трогаем:
  /// пользователь мог поправить путь под себя.
  void _onSavePathsProgress(
    SavePathsProgressChanged event,
    Emitter<LibraryState> emit,
  ) => emit(state.copyWith(savePathsProgress: event.progress));

  /// Смотрит, что изменилось, пока игра работала.
  ///
  /// База путей знает не всякую игру — торрент-релизов в ней нет вовсе. Зато
  /// игра сама создаёт себе папку под сейвы, и промежуток её работы нам
  /// известен точно.
  Future<void> _onSaveHintsRequested(
    SaveHintsRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final List<SavePathSuggestion> found;
    try {
      found = await SaveActivityWatch.changedSince(
        event.since,
        gameTitle: event.game.title,
        gameDir: event.game.installDir,
        roots: _saveRoots(),
      );
    } on Object {
      // Обход папок — дело подсобное: не вышло, значит подсказок не будет.
      return;
    }

    final fresh = _withoutKnownPaths(event.game, found);
    if (fresh.isEmpty) return;

    emit(
      state.copyWith(
        saveHints: {...state.saveHints, event.game.id: fresh},
        notice: _notice(_l.noticeSaveHints(fresh.length, event.game.title)),
      ),
    );
  }

  /// Отсеивает то, что уже покрыто заданными правилами: подсказывать
  /// известное — значит приучить не читать подсказки вовсе.
  static List<SavePathSuggestion> _withoutKnownPaths(
    Game game,
    List<SavePathSuggestion> found,
  ) {
    final known = <String>[];
    for (final rule in game.saveProfile.rules) {
      final resolved = rule.resolve(gameDir: game.installDir);
      if (resolved != null) known.add(p.normalize(resolved));
    }
    return [
      for (final item in found)
        if (!known.any(
          (path) => p.equals(path, item.path) || p.isWithin(path, item.path),
        ))
          item,
    ];
  }

  Future<void> _onSaveHintsAccepted(
    SaveHintsAccepted event,
    Emitter<LibraryState> emit,
  ) async {
    final current = state.gameById(event.game.id);
    if (current == null || event.suggestions.isEmpty) return;

    final existing = current.saveProfile.rules.map((r) => r.template).toSet();
    final templates = [
      for (final item in event.suggestions)
        if (!existing.contains(item.template)) item.template,
    ];
    if (templates.isEmpty) {
      emit(state.copyWith(saveHints: _withoutHints(current.id)));
      return;
    }

    final labels = SavePathRule.labelsFor([...existing, ...templates]);
    final added = <SavePathRule>[
      for (var i = 0; i < templates.length; i++)
        SavePathRule(
          id: const Uuid().v4(),
          label: labels[existing.length + i],
          template: templates[i],
        ),
    ];

    final games = [...state.games];
    games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
      saveProfile: current.saveProfile.copyWith(
        rules: [...current.saveProfile.rules, ...added],
      ),
    );
    emit(
      state.copyWith(
        games: games,
        saveHints: _withoutHints(current.id),
        notice: _notice(
          _l.noticePathsAdded(_l.sourceWatch, added.length, current.title),
        ),
      ),
    );
    _schedulePersist();
  }

  void _onSaveHintsDismissed(
    SaveHintsDismissed event,
    Emitter<LibraryState> emit,
  ) => emit(state.copyWith(saveHints: _withoutHints(event.gameId)));

  Map<String, List<SavePathSuggestion>> _withoutHints(String gameId) => {
    for (final entry in state.saveHints.entries)
      if (entry.key != gameId) entry.key: entry.value,
  };

  /// Ищет пути в базе и доводит их до состояния, пригодного для правила.
  ///
  /// База пишет пути с масками («любой профиль») и плейсхолдером `<base>` —
  /// папкой самой игры. Первое раскрывается по тому, что лежит на диске,
  /// второе мы знаем сами: игру ставил этот же лончер.
  Future<_FoundPaths?> _lookupPaths(SavePathsLookupRequested event) async {
    await savePaths.ensureLoaded(refresh: event.refresh);
    final entry = savePaths.find(
      title: event.game.title,
      steamAppId: event.game.steamAppId,
    );
    if (entry == null) return null;

    final gameDir = event.game.installDir;
    final templates = <String>[];
    for (final template in entry.templates) {
      for (final resolved in await SavePathGlobs.expand(
        template,
        gameDir: gameDir,
      )) {
        if (!templates.contains(resolved)) templates.add(resolved);
      }
    }

    return _FoundPaths(
      title: entry.title,
      templates: SavePathRule.withoutNested(templates),
      sourceTemplates: entry.templates,
      registryKeys: entry.registryKeys,
    );
  }

  Future<void> _onSavePathsLookup(
    SavePathsLookupRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = savePathsKey(event.game.id);
    final game = state.gameById(event.game.id);
    if (game == null ||
        state.isBusy(key) ||
        (event.automatic &&
            (game.steamAppId == null || game.savePathsLookupAttempted))) {
      return;
    }
    emit(state.copyWith(busy: _withBusy(key, true)));
    // Указатель хода гасим в любом случае: оставшись висеть, он врал бы
    // о продолжающейся работе.
    void done() {
      if (!_closing) add(const SavePathsProgressChanged(null));
    }

    try {
      _replaceGame(game.copyWith(savePathsLookupAttempted: true), emit);
      await persist();
      final entry = await _lookupPaths(
        SavePathsLookupRequested(game, refresh: event.refresh),
      );
      if (_closing) return;

      if (entry == null) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: event.automatic
                ? state.notice
                : _notice(_l.noticePathsNothingFound),
          ),
        );
        done();
        return;
      }

      final current = state.gameById(event.game.id);
      if (current == null || current.addedAt != game.addedAt) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        done();
        return;
      }

      final existing = current.saveProfile.rules.map((r) => r.template).toSet();
      final added = <SavePathRule>[
        for (final template in entry.templates)
          if (!existing.contains(template))
            SavePathRule(
              id: const Uuid().v4(),
              label: entry.labelFor(template),
              template: template,
            ),
      ];

      final games = [...state.games];
      games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
        ludusaviTemplates: entry.sourceTemplates,
        ludusaviResolvedPaths: {
          ...current.ludusaviResolvedPaths,
          ...entry.templates,
        }.toList(),
        saveProfile: current.saveProfile.copyWith(
          rules: [...current.saveProfile.rules, ...added],
        ),
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: event.automatic
              ? state.notice
              : _notice(
                  entry.isEmpty
                      ? _l.noticePathsNothingFound
                      : added.isEmpty
                      ? _l.noticePathsAlreadySet
                      : entry.describe(_l, added.length),
                ),
        ),
      );
      await persist();
      done();
    } on Object catch (error) {
      done();
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Снимает сохранения всех настроенных игр и складывает пакеты в папку —
  /// то, с чего начинается переезд на другое устройство.

  Future<void> _onBulkExport(
    BulkExportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(bulkKey, true)));

    for (final game in state.games) {
      await _resolveStoredPaths(game, emit);
    }

    final result = await _bulk.exportAll(
      games: state.games,
      destinationDir: event.destinationDir,
      // Снимок ложится в состояние сразу, а не всей пачкой в конце:
      // выгрузка большой библиотеки идёт минуты.
      onSnapshot: (snapshot) =>
          emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
    );

    await persist();
    emit(
      state.copyWith(
        busy: _withBusy(bulkKey, false),
        bulkReport: result.report,
        notice: _notice(result.message, isError: result.isError),
      ),
    );
  }

  Future<void> _onBulkImport(
    BulkImportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(bulkKey, true)));

    final BulkResult result;
    try {
      result = await _bulk.importAll(
        games: state.games,
        sourceDir: event.sourceDir,
        overwriteNewer: event.overwriteNewer,
        onSnapshot: (snapshot) =>
            emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
      );
    } on Object catch (error) {
      // Папку не прочитать — разбирать нечего: это провал всей операции,
      // а не исход отдельной игры, и отчёта по играм тут не будет.
      emit(
        state.copyWith(
          busy: _withBusy(bulkKey, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
      return;
    }

    await persist();
    emit(
      state.copyWith(
        busy: _withBusy(bulkKey, false),
        bulkReport: result.report,
        notice: _notice(result.message, isError: result.isError),
      ),
    );
  }

  Future<void> _onSyncScanRequested(
    SyncFolderScanRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      emit(state.copyWith(syncPackages: const [], syncScanned: true));
      return;
    }
    emit(state.copyWith(scanningSync: true));
    try {
      final packages = await _saves.scanSyncFolder(folder);
      emit(
        state.copyWith(
          syncPackages: packages,
          scanningSync: false,
          syncScanned: true,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          scanningSync: false,
          syncScanned: true,
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onSyncPackageApplied(
    SyncPackageApplied event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(state.copyWith(snapshots: _withSnapshot(snapshot)));

      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: snapshot,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice(_l.noticeRestoreDone(report.filesWritten))
              : _notice(
                  _l.noticeUnresolvedShort(report.unresolved.join(', ')),
                  isError: true,
                ),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Future<void> close() async {
    _closing = true;
    // Отложенную запись именно дожидаемся: запущенная и брошенная, она не
    // успевает лечь на диск, и последнее изменение теряется при выходе.
    final pending = _persistTimer?.isActive ?? false;
    _persistTimer?.cancel();
    if (pending) await persist();
    await _store.flush();
    _launcher.runningIds.removeListener(_pushRunningGames);
    _launcher.dispose();
    return super.close();
  }
}

/// Найденные пути и то, откуда они взялись.
class _FoundPaths {
  _FoundPaths({
    required this.title,
    required this.templates,
    this.sourceTemplates = const [],
    this.registryKeys = const [],
  });

  final String title;
  final List<String> templates;
  final List<String> sourceTemplates;
  final List<String> registryKeys;

  bool get isEmpty => templates.isEmpty;

  late final List<String> _labels = SavePathRule.labelsFor(templates);

  String labelFor(String template) => _labels[templates.indexOf(template)];

  String describe(L l, int added) {
    final message = l.noticePathsAdded(l.sourceDatabase, added, title);
    if (registryKeys.isEmpty) return message;
    // Реестр мы не переносим, но умолчать о нём нельзя: иначе пользователь
    // решит, что забрал сейв целиком.
    return l.noticeRegistryLeft(message, registryKeys.length);
  }
}
