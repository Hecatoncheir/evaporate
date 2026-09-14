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
import '../../models/game_rating.dart';
import '../../models/save_profile.dart';
import '../../models/bulk_report.dart';
import '../../models/catalog_progress.dart';
import '../../models/save_snapshot.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/launch/steam_shortcuts.dart';
import '../../services/metadata/steam_catalog.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/saves/ludusavi_catalog.dart';
import '../../services/saves/save_activity_watch.dart';
import '../../services/saves/save_path_finder.dart';
import '../../services/saves/save_path_globs.dart';
import '../../services/saves/bulk_transfer.dart';
import '../../services/saves/save_manager.dart';
import '../../services/system/app_log.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'library_event.dart';
part 'library_state.dart';
part 'library_saves.dart';
part 'library_metadata.dart';

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
    SteamShortcuts? steamShortcuts,
    LudusaviCatalog? savePaths,
    L Function()? localizations,
    List<SaveRoot> Function()? saveRoots,
    this.automaticMetadata = true,
  }) : steam = steam ?? SteamCatalog(proxy: () => settings.state.proxy),
       _steamShortcuts =
           steamShortcuts ??
           SteamShortcuts(
             localizations: localizations ?? _defaultLocalizations,
           ),
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
    // По одному запросу за раз, а не все разом. Загрузка библиотеки
    // ставит поиск метаданных каждой игре сразу, а Bloc по умолчанию
    // обрабатывает события параллельно: сорок игр давали сорок
    // одновременных соединений со Steam, каждое со своим HttpClient.
    // Steam на такой залп отвечает отказом — и, поскольку маркер «уже
    // пробовали» записан, игры оставались без обложек навсегда.
    //
    // Цена — очередь: ручной поиск, нажатый во время разбора большой
    // библиотеки, дождётся своей очереди. Это лучше, чем залп, который
    // не доходит ни для одной игры.
    on<SteamLookupRequested>(
      _onSteamLookup,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SavePathsLookupRequested>(
      _onSavePathsLookup,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SteamShortcutRequested>(_onSteamShortcut);
    on<SavePathsProgressChanged>(_onSavePathsProgress);
    on<MetadataRetryRequested>(_onMetadataRetry);
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

  /// Заведение игры в Steam сторонним ярлыком. Подменяется в тестах:
  /// настоящий Steam на машине прогона не установлен.
  final SteamShortcuts _steamShortcuts;

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

  /// Ключ отдельный от [steamKey]: поиск обложки в каталоге и запись
  /// ярлыка — разные дела, и занятость одного не должна гасить кнопку
  /// другого.
  static String steamShortcutKey(String gameId) => 'steam-shortcut:$gameId';

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

  Notice _notice(String message, {bool isError = false}) {
    // SnackBar живёт секунды, а рассказ о случившемся доходит через день.
    if (isError) AppLog.instance.write('библиотека: $message');
    return Notice(message: message, seq: ++_noticeSeq, isError: isError);
  }

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
      steamAppId: event.steamAppId,
      saveProfile: SaveProfile(
        autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
        autoSnapshotOnLaunch: settings.state.autoSnapshotOnLaunch,
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
      } on Object catch (error) {
        // Файл мог быть уже удалён вручную.
        AppLog.instance.write('удаление игры: снимок ${snapshot.id}', error);
      }
    }
    await _collectGarbage();
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
      await _snapshotBeforeLaunch(game, emit);
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

  /// Снимает сейв до того, как игра начнёт работать.
  ///
  /// Автоснимок после выхода бесполезен против игры, которая портит своё
  /// сохранение при старте: к моменту выхода портить уже нечего, и снимок
  /// закрепит испорченное. Поэтому снимаем именно до запуска и именно
  /// дожидаясь: снимок, снятый параллельно со стартом игры, застаёт файлы
  /// в неизвестном состоянии, а значит, не годится ни на что.
  ///
  /// Провал запускать не мешает: играть человек собрался, а резервная
  /// копия — услуга, а не условие. Молча провалиться она при этом не
  /// вправе — об этом сообщает система, как и о неудавшемся автоснимке
  /// после выхода.
  Future<void> _snapshotBeforeLaunch(
    Game game,
    Emitter<LibraryState> emit,
  ) async {
    final profile = game.saveProfile;
    if (!profile.autoSnapshotOnLaunch) return;
    if (!profile.isConfigured && game.ludusaviTemplates.isEmpty) return;

    try {
      final snapshot = await _saves.createSnapshot(
        game,
        origin: SnapshotOrigin.autoOnLaunch,
      );
      emit(state.copyWith(snapshots: _withSnapshot(snapshot)));
      await _prune(game.id, emit);
      await persist();
    } on SaveNothingFoundException {
      // Сейвов ещё нет — первый запуск. Сохранять нечего, и это не беда.
    } on Object catch (error) {
      _notifySystem(
        AppNotification(
          title: _l.noticeSnapshotFailed,
          body: _l.noticeSaveFailedBody(
            game.title,
            error is SaveException ? error.message : error.toString(),
          ),
          kind: NotificationKind.saveFailed,
        ),
      );
    }
  }

  void _onRunningGamesChanged(
    RunningGamesChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(runningIds: event.ids));
  }

  // -------------------------------------------------------------- сейвы

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
