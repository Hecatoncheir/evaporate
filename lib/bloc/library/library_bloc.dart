import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/catalog_progress.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../services/launch/drop_import.dart';
import '../../services/launch/executable_finder.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/steam_shortcuts.dart';
import '../../services/metadata/cover_cache.dart';
import '../../services/metadata/game_metadata_fetcher.dart';
import '../../services/metadata/steam_catalog.dart';
import '../../services/saves/ludusavi_catalog.dart';
import '../../services/saves/save_path_globs.dart';
import '../../services/system/app_log.dart';
import '../../services/system/file_manager.dart';
import '../bloc_common.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'library_drops.dart';
part 'library_edits.dart';
part 'library_event.dart';
part 'library_metadata.dart';
part 'library_state.dart';

/// Игра завершилась: кто и сколько отыграл.
///
/// Запись, а не класс: у неё нет ни поведения, ни собственной жизни —
/// это пара значений, которую библиотека объявляет и тут же забывает.
typedef GameExit = ({Game game, Duration played});

/// Библиотека игр — единственный источник правды о них для интерфейса.
/// Сохранения держит `SavesBloc`, а библиотека о нём не знает.
///
/// Ошибки наружу не выбрасываются: обработчики кладут результат в [Notice],
/// а экраны показывают его через `BlocListener`.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState>
    with NoticeBloc<LibraryState>, BusyBloc<LibraryEvent, LibraryState> {
  LibraryBloc({
    required AppPaths paths,
    required this.settings,
    JsonStore? store,
    GameLauncher? launcher,
    SteamCatalog? steam,
    CoverCache? covers,
    GameMetadataFetcher? metadata,
    SteamShortcuts? steamShortcuts,
    LudusaviCatalog? savePaths,
    FileManager? fileManager,
    Future<List<DropCandidate>> Function(Iterable<String>)? inspectDrop,
    L Function()? localizations,
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
       _store = store ?? JsonStore(paths.libraryFile),
       covers =
           covers ??
           CoverCache(coversDir: paths.coversDir, shotsDir: paths.shotsDir),
       _launcher = launcher ?? GameLauncher(),
       _fileManager = fileManager ?? FileManager(),
       _inspectDrop = inspectDrop ?? DropImport.inspect,
       super(const LibraryState()) {
    // В списке инициализаторов `steam` — ещё параметр: одноимённое поле
    // он закрывает, а сборщику нужен именно готовый каталог.
    this.metadata = metadata ?? GameMetadataFetcher(this.steam);
    on<LibraryLoadRequested>(_onLoadRequested);
    on<GameAdded>(_onGameAdded);
    on<GameStatusChanged>(_onStatusChanged);
    on<GameDownloadStarted>(_onDownloadStarted);
    on<GameDownloadLinked>(_onDownloadLinked);
    on<GameDownloadDropped>(_onDownloadDropped);
    on<GameDownloadFinished>(_onDownloadFinished);
    on<GameDownloadRejected>(_onDownloadRejected);
    on<GameExecutableSet>(_onExecutableSet);
    on<GameExecutableDetectRequested>(_onExecutableDetectRequested);
    on<GameExecutablePickDismissed>(_onExecutablePickDismissed);
    on<GameFolderOpenRequested>(_onFolderOpenRequested);
    on<FilesDropped>(_onFilesDropped);
    on<ScannedGamesAdded>(_onScannedGamesAdded);
    on<GameInstallDirSet>(_onInstallDirSet);
    on<SaveRulesAdded>(_onSaveRulesAdded);
    on<SaveRuleRemoved>(_onSaveRuleRemoved);
    on<AutoSnapshotChanged>(_onAutoSnapshotChanged);
    on<GameRemoved>(_onGameRemoved);
    on<GameLaunchRequested>(_onLaunchRequested);
    on<GameStopRequested>(_onStopRequested);
    on<GameExited>(_onGameExited);
    on<RunningGamesChanged>(_onRunningGamesChanged);
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
    on<MetadataRefreshRequested>(_onMetadataRefresh);
    // this нужен явно: без него имя разрешается в параметр конструктора.
    this.savePaths.onProgress = (value) {
      if (!_closing) add(SavePathsProgressChanged(value));
    };

    _launcher.runningIds.addListener(_pushRunningGames);
  }

  final SettingsBloc settings;

  /// Отключается в изолированных тестах без сетевых сервисов.
  final bool automaticMetadata;

  /// Обложки и кадры — файлы, и правила у них свои: трогаем только свой
  /// кэш. Отсюда отдельный сервис, а не `File` по месту.
  final CoverCache covers;

  /// Кто ходит в Steam за `appid`, описанием, обложкой и оценкой.
  ///
  /// Поле, а не `late`: то же самое нужно `_onMetadataRefresh`, и оба
  /// подменяются в тестах одним параметром конструктора.
  late final GameMetadataFetcher metadata;

  /// Откуда брать переводы для уведомлений.
  ///
  /// У блока нет `BuildContext`, поэтому локализация приходит извне функцией:
  /// язык может смениться на ходу, и держать один объект нельзя. По умолчанию
  /// русский — тесты проверяют текст уведомлений и языка не задают.
  final L Function() _localizations;

  L get _l => _localizations();

  /// Каталог Steam: по имени раздачи находит название, описание и обложку.
  final SteamCatalog steam;

  /// Заведение игры в Steam сторонним ярлыком. Подменяется в тестах:
  /// настоящий Steam на машине прогона не установлен.
  final SteamShortcuts _steamShortcuts;

  /// Открытая база путей сохранений — та часть работы, которую иначе
  /// пришлось бы делать руками для каждой игры.
  final LudusaviCatalog savePaths;

  final JsonStore _store;

  /// Запускает игры и следит за их процессами.
  final GameLauncher _launcher;
  final FileManager _fileManager;

  /// Разбор брошенного в окно. Подменяется в прогоне: настоящий ходит по
  /// диску, а проверять нужно и тот случай, когда он не смог.
  final Future<List<DropCandidate>> Function(Iterable<String>) _inspectDrop;

  /// Кто вышел из игры и сколько отыграл.
  ///
  /// Публикуется наружу, а не решается здесь: что делать с сохранениями
  /// после выхода, знает `SavesBloc`. Зависимость идёт в одну сторону — он
  /// знает библиотеку, библиотека о нём нет, — и передать ему событие
  /// напрямую нечем.
  // ignore: avoid_public_bloc_methods
  Stream<GameExit> get gameExits => _exits.stream;

  /// Игра ушла из библиотеки: её снимки больше никому не нужны.
  // ignore: avoid_public_bloc_methods
  Stream<String> get gameRemovals => _removals.stream;

  /// Что завелось из брошенного в окно: загрузки ставят раздачи в очередь,
  /// навигация подсвечивает последнюю.
  // ignore: avoid_public_bloc_methods
  Stream<DroppedGames> get gameDrops => _drops.stream;

  /// Что сделать с сохранениями перед запуском игры.
  ///
  /// Ставит его блок сохранений — снимок его дело, — но **дождаться** его
  /// должна библиотека, а события не дожидаются. Отсюда хук, а не событие.
  // ignore: avoid_public_bloc_methods
  Future<void> Function(Game game)? beforeLaunch;

  final _exits = StreamController<GameExit>.broadcast();
  final _removals = StreamController<String>.broadcast();
  final _drops = StreamController<DroppedGames>.broadcast();

  Timer? _persistTimer;
  bool _closing = false;

  /// Кто сейчас запущен. Загрузки смотрят на это, чтобы снять предел
  /// скорости на время игры, — им нужен сам источник, а не снимок в
  /// состоянии: он меняется от процесса, а не от события.
  // ignore: avoid_public_bloc_methods
  GameLauncher get launcher => _launcher;

  static L _defaultLocalizations() => LRu();

  static String steamKey(String gameId) => 'steam:$gameId';

  /// Ключ отдельный от [steamKey]: поиск обложки в каталоге и запись
  /// ярлыка — разные дела, и занятость одного не должна гасить кнопку
  /// другого.
  static String steamShortcutKey(String gameId) => 'steam-shortcut:$gameId';

  static String savePathsKey(String gameId) => 'paths:$gameId';

  static String launchKey(String gameId) => 'launch:$gameId';

  void _pushRunningGames() =>
      add(RunningGamesChanged(_launcher.runningIds.value));

  @override
  String get logTag => 'библиотека';

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), persist);
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    await _writeGames(state.games);
  }

  Future<void> _writeGames(List<Game> games) => _store.write({
    'version': 1,
    'games': games.map((g) => g.toJson()).toList(),
  });

  // ---------------------------------------------------------------- игры

  Future<void> _onLoadRequested(
    LibraryLoadRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final json = await _store.readAs((json) {
      if ((json['version'] ?? 1) != 1 ||
          (json['games'] != null && json['games'] is! List)) {
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
    if (damaged) {
      await _store.quarantine();
      // Карантин переименовывает файл, и уцелевшие игры остались бы только
      // в памяти: у сложившейся библиотеки правок на старте нет, писать их
      // некому, и второй запуск находил пустоту. Пишем до того, как
      // объявить библиотеку загруженной. Не записалось — загрузку это не
      // отменяет: игры в памяти есть, и следующая правка попробует снова.
      try {
        await _writeGames(games);
      } on Object catch (error) {
        AppLog.instance.write('запись библиотеки после карантина', error);
      }
    }
    emit(
      state.copyWith(
        games: games,
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
        : notice(_l.noticeStorageRecovered(path), isError: true);
  }

  void _onGameAdded(GameAdded event, Emitter<LibraryState> emit) {
    final title = event.title.trim();
    final game = Game(
      id: event.id,
      title: title.isEmpty ? _l.untitled : title,
      addedAt: DateTime.now(),
      installDir: event.installDir,
      executablePath: event.executablePath,
      status: event.status,
      download: DownloadLink(source: event.source),
      details: GameDetails(steamAppId: event.steamAppId),
      saveProfile: SaveProfile(
        autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
        autoSnapshotOnLaunch: settings.state.autoSnapshotOnLaunch,
      ),
    );
    emit(state.copyWith(games: [...state.games, game]));
    _schedulePersist();
    _queueMetadata(game);
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
    emit(
      state.copyWith(games: state.games.where((g) => g.id != game.id).toList()),
    );
    await persist();
    // Снимки этой игры уносит блок сохранений: список их держит он.
    _removals.add(game.id);

    await covers.deleteCover(game.details.coverPath);
    await covers.deleteShots(game.details.shotPaths);
    if (event.deleteFiles) await _deleteInstallDir(game);
  }

  /// Убирает саму игру с диска — но только внутри папки загрузок.
  ///
  /// Страховка от опечаток: путь установки задаёт человек, и снести по
  /// нему что-нибудь за пределами своей папки приложение не вправе.
  Future<void> _deleteInstallDir(Game game) async {
    final installDir = game.installDir;
    if (installDir == null) return;
    final dir = Directory(installDir);
    if (!await dir.exists()) return;
    if (!p.isWithin(settings.state.installDir, dir.path)) return;
    await dir.delete(recursive: true);
  }

  // ------------------------------------------------------------- запуск

  Future<void> _onLaunchRequested(
    GameLaunchRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final key = launchKey(game.id);
    // Второе нажатие, пока идёт снимок перед запуском, — не второй запуск.
    if (state.isBusy(key)) return;
    await busyWhile(emit, key, () async {
      // Снимок перед запуском ставит блок сохранений, а дождаться его
      // обязаны мы: игра начнёт писать в сейвы сразу, и копия, снятая
      // параллельно со стартом, застаёт файлы в неизвестном состоянии.
      await beforeLaunch?.call(game);
      await _launcher.launch(
        game,
        onExit: (exited, played, exitCode) => add(
          GameExited(gameId: exited.id, played: played, exitCode: exitCode),
        ),
      );
      // Игра из события захвачена до снимка и запуска — секунды назад;
      // правка, пришедшая за это время, живёт только в состоянии.
      _edit(
        game.id,
        emit,
        (current) =>
            current.copyWith(status: GameStatus.running, lastError: null),
      );
      // Запуск удался — говорить об этом нечего: человек и так увидит игру.
      return null;
    });
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
      play: PlayStats(
        playtime: current.play.playtime + counted,
        lastPlayed: DateTime.now(),
      ),
    );
    final games = [...state.games];
    games[games.indexWhere((g) => g.id == event.gameId)] = updated;
    emit(state.copyWith(games: games));
    _schedulePersist();

    // Что делать с сохранениями после выхода, решает блок сохранений.
    _exits.add((game: updated, played: event.played));
  }

  void _onRunningGamesChanged(
    RunningGamesChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(runningIds: event.ids));
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
    await _exits.close();
    await _removals.close();
    await _drops.close();
    _launcher.runningIds.removeListener(_pushRunningGames);
    _launcher.dispose();
    return super.close();
  }
}
