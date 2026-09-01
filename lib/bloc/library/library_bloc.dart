import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../core/json_store.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/metadata/steam_catalog.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/saves/ludusavi_catalog.dart';
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
    SaveManager? saveManager,
    GameLauncher? launcher,
    NotificationService? notifications,
    SteamCatalog? steam,
    LudusaviCatalog? savePaths,
  }) : steam = steam ?? SteamCatalog(proxy: () => settings.state.proxy),
       savePaths =
           savePaths ??
           LudusaviCatalog(
             cacheFile: paths.savePathsCacheFile,
             proxy: () => settings.state.proxy,
           ),
       notifications = notifications ?? const NoopNotificationService(),
       _store = JsonStore(paths.libraryFile),
       _saves = saveManager ?? SaveManager(paths: paths),
       _launcher = launcher ?? GameLauncher(),
       super(const LibraryState()) {
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
    on<BulkExportRequested>(_onBulkExport);
    on<BulkImportRequested>(_onBulkImport);
    on<SyncFolderScanRequested>(_onSyncScanRequested);
    on<SyncPackageApplied>(_onSyncPackageApplied);

    _launcher.runningIds.addListener(_pushRunningGames);
  }

  final SettingsBloc settings;

  /// Автоснимок после выхода из игры молчалив по замыслу, но его провал
  /// пользователь обязан заметить — иначе узнает, только потеряв прогресс.
  final NotificationService notifications;

  /// Каталог Steam: по имени раздачи находит название, описание и обложку.
  final SteamCatalog steam;

  /// Открытая база путей сохранений — та часть работы, которую иначе
  /// пришлось бы делать руками для каждой игры.
  final LudusaviCatalog savePaths;
  final JsonStore _store;
  final SaveManager _saves;
  final GameLauncher _launcher;

  Timer? _persistTimer;
  int _noticeSeq = 0;

  /// Чтение манифеста чужого `.evsave` состояния не меняет, поэтому диалог
  /// подтверждения обращается к менеджеру напрямую.
  SaveManager get saveManager => _saves;

  GameLauncher get launcher => _launcher;

  static String snapshotKey(String gameId) => 'snapshot:$gameId';

  static String steamKey(String gameId) => 'steam:$gameId';

  static String savePathsKey(String gameId) => 'paths:$gameId';

  /// Ключ занятости для операций над всей библиотекой сразу.
  static const bulkKey = 'bulk';

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
    final json = await _store.read();
    if (json == null) {
      emit(state.copyWith(loaded: true));
      return;
    }
    final games = (json['games'] as List<dynamic>? ?? [])
        .map((e) => Game.fromJson(e as Map<String, dynamic>))
        .toList();
    final snapshots = <String, List<SaveSnapshot>>{};
    (json['snapshots'] as Map<String, dynamic>? ?? {}).forEach((gameId, value) {
      snapshots[gameId] = (value as List<dynamic>)
          .map((e) => SaveSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    });
    emit(state.copyWith(games: games, snapshots: snapshots, loaded: true));
  }

  void _onGameAdded(GameAdded event, Emitter<LibraryState> emit) {
    final title = event.title.trim();
    final game = Game(
      id: event.id,
      title: title.isEmpty ? 'Без названия' : title,
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
  }

  void _onGameUpdated(GameUpdated event, Emitter<LibraryState> emit) {
    final index = state.games.indexWhere((g) => g.id == event.game.id);
    if (index == -1) return;
    final games = [...state.games];
    games[index] = event.game;
    emit(state.copyWith(games: games));
    _schedulePersist();
  }

  Future<void> _onGameRemoved(
    GameRemoved event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    final removed = snapshots.remove(game.id) ?? const <SaveSnapshot>[];
    emit(
      state.copyWith(
        games: state.games.where((g) => g.id != game.id).toList(),
        snapshots: snapshots,
      ),
    );
    await persist();

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
        updated.saveProfile.isConfigured) {
      add(SnapshotRequested(updated, origin: SnapshotOrigin.autoOnExit));
    }
  }

  void _onRunningGamesChanged(
    RunningGamesChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(runningIds: event.ids));
  }

  // -------------------------------------------------------------- сейвы

  Future<void> _onSnapshotRequested(
    SnapshotRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final silent = event.origin == SnapshotOrigin.autoOnExit;
    final key = snapshotKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));

    try {
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
                  'Снимок готов: ${snapshot.fileCount} файлов, '
                  '${_formatSize(snapshot.sizeBytes)}',
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
            title: 'Сохранения не сняты',
            body: '«${game.title}»: ${error.message}',
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
                  'Восстановлено ${report.filesWritten} файлов '
                  '(${_formatSize(report.bytesWritten)}).',
                )
              : _notice(
                  'Часть путей не сопоставилась: '
                  '${report.unresolved.join(', ')}. Остальное восстановлено.',
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
          notice: _notice('Снимок импортирован'),
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
      emit(state.copyWith(notice: _notice('Сохранено: ${event.destination}')));
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
      throw SaveException('Папка синхронизации не задана в настройках.');
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
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final match = await steam.bestMatch(event.query ?? event.game.title);
      if (match == null) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: _notice('В Steam ничего похожего не нашлось'),
          ),
        );
        return;
      }

      final current = state.gameById(event.game.id);
      if (current == null) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        return;
      }

      final index = state.games.indexWhere((g) => g.id == current.id);
      final games = [...state.games];
      games[index] = current.copyWith(
        steamAppId: match.appId,
        coverUrl: match.headerImage,
        description: match.description,
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: _notice('Найдено в Steam: ${match.name}'),
        ),
      );
      _schedulePersist();
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
  Future<void> _onSavePathsLookup(
    SavePathsLookupRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = savePathsKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      await savePaths.ensureLoaded(refresh: event.refresh);
      final entry = savePaths.find(
        title: event.game.title,
        steamAppId: event.game.steamAppId,
      );

      if (entry == null || entry.isEmpty) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: _notice('В базе путей ничего не нашлось для этой игры'),
          ),
        );
        return;
      }

      final current = state.gameById(event.game.id);
      if (current == null) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        return;
      }

      final existing = current.saveProfile.rules.map((r) => r.template).toSet();
      final added = <SavePathRule>[
        for (final template in entry.templates)
          if (!existing.contains(template))
            SavePathRule(
              id: const Uuid().v4(),
              label: 'Сохранения',
              template: template,
            ),
      ];

      if (added.isEmpty) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: _notice('Пути из базы уже заданы'),
          ),
        );
        return;
      }

      final games = [...state.games];
      games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
        saveProfile: current.saveProfile.copyWith(
          rules: [...current.saveProfile.rules, ...added],
        ),
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: _notice(
            'Добавлено путей из базы: ${added.length} (${entry.title})',
          ),
        ),
      );
      _schedulePersist();
    } on Object catch (error) {
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

    var exported = 0;
    var skipped = 0;
    final failed = <String>[];

    for (final game in state.games) {
      if (!game.saveProfile.isConfigured) {
        skipped++;
        continue;
      }
      try {
        final snapshot = await _saves.createSnapshot(game);
        emit(state.copyWith(snapshots: _withSnapshot(snapshot)));

        await _saves.exportSnapshot(
          snapshot,
          p.join(
            event.destinationDir,
            '${safeFileName(game.title)}${SaveSnapshot.fileExtension}',
          ),
        );
        exported++;
      } on SaveException {
        // Пути заданы, но файлов ещё нет — это не ошибка переноса.
        skipped++;
      } on Object {
        failed.add(game.title);
      }
    }

    await persist();
    emit(
      state.copyWith(
        busy: _withBusy(bulkKey, false),
        notice: _notice(
          failed.isEmpty
              ? 'Выгружено игр: $exported, пропущено: $skipped'
              : 'Выгружено: $exported, пропущено: $skipped, '
                    'с ошибкой: ${failed.join(', ')}',
          isError: failed.isNotEmpty,
        ),
      ),
    );
  }

  /// Разбирает папку с пакетами и раскладывает сохранения по играм —
  /// вторая половина переезда, уже на новом устройстве.
  Future<void> _onBulkImport(
    BulkImportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(bulkKey, true)));

    var applied = 0;
    final unmatched = <String>[];
    final failed = <String>[];

    try {
      final packages = await _saves.scanSyncFolder(event.sourceDir);
      for (final package in packages) {
        final game = _matchGame(package.snapshot.gameTitle);
        if (game == null) {
          unmatched.add(package.snapshot.gameTitle);
          continue;
        }
        try {
          final snapshot = await _saves.importPackage(package.path, game: game);
          emit(state.copyWith(snapshots: _withSnapshot(snapshot)));
          final report = await _saves.restoreSnapshot(
            game: game,
            snapshot: snapshot,
          );
          if (report.backup != null) {
            emit(state.copyWith(snapshots: _withSnapshot(report.backup!)));
          }
          if (report.isComplete) {
            applied++;
          } else {
            failed.add(game.title);
          }
        } on Object {
          failed.add(game.title);
        }
      }
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(bulkKey, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
      return;
    }

    await persist();
    final parts = <String>[
      'применено: $applied',
      if (unmatched.isNotEmpty) 'нет такой игры: ${unmatched.length}',
      if (failed.isNotEmpty) 'с ошибкой: ${failed.length}',
    ];
    emit(
      state.copyWith(
        busy: _withBusy(bulkKey, false),
        notice: _notice(
          parts.join(', '),
          isError: failed.isNotEmpty || unmatched.isNotEmpty,
        ),
      ),
    );
  }

  /// Идентификаторы игр на разных устройствах не совпадают, поэтому
  /// пакеты сопоставляются по названию.
  Game? _matchGame(String title) {
    final wanted = title.trim().toLowerCase();
    for (final game in state.games) {
      if (game.title.trim().toLowerCase() == wanted) return game;
    }
    return null;
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
              ? _notice('Готово: ${report.filesWritten} файлов восстановлено.')
              : _notice(
                  'Не сопоставились пути: ${report.unresolved.join(', ')}.',
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
  Future<void> close() {
    // Отложенная запись не должна пропасть вместе с таймером.
    if (_persistTimer?.isActive ?? false) unawaited(persist());
    _persistTimer?.cancel();
    _launcher.runningIds.removeListener(_pushRunningGames);
    _launcher.dispose();
    return super.close();
  }
}
