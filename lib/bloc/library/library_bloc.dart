import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/catalog_progress.dart';
import '../../models/game.dart';
import '../../models/game_rating.dart';
import '../../models/save_profile.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/launch/steam_shortcuts.dart';
import '../../services/metadata/steam_catalog.dart';
import '../../services/saves/ludusavi_catalog.dart';
import '../../services/saves/save_path_globs.dart';
import '../../services/system/app_log.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'library_event.dart';
part 'library_metadata.dart';
part 'library_state.dart';

/// Библиотека игр и их сохранений — единственный источник правды для UI.
///
/// Ошибки наружу не выбрасываются: обработчики кладут результат в [Notice],
/// а экраны показывают его через `BlocListener`.
/// Игра завершилась: кто и сколько отыграл.
///
/// Запись, а не класс: у неё нет ни поведения, ни собственной жизни —
/// это пара значений, которую библиотека объявляет и тут же забывает.
typedef GameExit = ({Game game, Duration played});

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({
    required AppPaths paths,
    required this.settings,
    JsonStore? store,
    GameLauncher? launcher,
    SteamCatalog? steam,
    SteamShortcuts? steamShortcuts,
    LudusaviCatalog? savePaths,
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
       _coversDir = paths.coversDir,
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
    // this нужен явно: без него имя разрешается в параметр конструктора.
    this.savePaths.onProgress = (value) {
      if (!_closing) add(SavePathsProgressChanged(value));
    };

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

  /// Каталог Steam: по имени раздачи находит название, описание и обложку.
  final SteamCatalog steam;

  /// Заведение игры в Steam сторонним ярлыком. Подменяется в тестах:
  /// настоящий Steam на машине прогона не установлен.
  final SteamShortcuts _steamShortcuts;

  /// Открытая база путей сохранений — та часть работы, которую иначе
  /// пришлось бы делать руками для каждой игры.
  final LudusaviCatalog savePaths;

  final JsonStore _store;

  /// Перенос сохранений всей библиотеки: единственная операция, идущая по
  /// всем играм разом, и единственная со своим счётом исходов.
  final GameLauncher _launcher;

  /// Кто вышел из игры и сколько отыграл.
  ///
  /// Публикуется наружу, а не решается здесь: что делать с сохранениями
  /// после выхода, знает `SavesBloc`. Зависимость идёт в одну сторону — он
  /// знает библиотеку, библиотека о нём нет, — и передать ему событие
  /// напрямую нечем.
  Stream<GameExit> get gameExits => _exits.stream;

  /// Игра ушла из библиотеки: её снимки больше никому не нужны.
  Stream<String> get gameRemovals => _removals.stream;

  /// Что сделать с сохранениями перед запуском игры.
  ///
  /// Ставит его блок сохранений — снимок его дело, — но **дождаться** его
  /// должна библиотека, а события не дожидаются. Отсюда хук, а не событие.
  Future<void> Function(Game game)? beforeLaunch;

  final _exits = StreamController<GameExit>.broadcast();
  final _removals = StreamController<String>.broadcast();

  Timer? _persistTimer;
  bool _closing = false;
  int _noticeSeq = 0;

  /// Чтение манифеста чужого `.evsave` состояния не меняет, поэтому диалог
  /// подтверждения обращается к менеджеру напрямую.

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

  Notice _notice(String message, {bool isError = false}) {
    // SnackBar живёт секунды, а рассказ о случившемся доходит через день.
    if (isError) AppLog.instance.write('библиотека: $message');
    return Notice(message: message, seq: ++_noticeSeq, isError: isError);
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

  /// Гасит указатель занятости и, если есть что сказать, показывает
  /// сообщение. Работа, которую человек не просил, идёт молча — ей
  /// сообщение не нужно.
  void _finishBusy(
    Emitter<LibraryState> emit,
    String key, {
    String? message,
    bool isError = false,
  }) {
    emit(
      state.copyWith(
        busy: _withBusy(key, false),
        notice: message == null
            ? state.notice
            : _notice(message, isError: isError),
      ),
    );
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
    });
  }

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
    if (damaged) await _store.quarantine();
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
    emit(
      state.copyWith(games: state.games.where((g) => g.id != game.id).toList()),
    );
    await persist();
    // Снимки этой игры уносит блок сохранений: список их держит он.
    _removals.add(game.id);

    final cover = game.coverPath;
    if (cover != null && p.isWithin(_coversDir, cover)) {
      final file = File(cover);
      if (await file.exists()) await file.delete();
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

    // Что делать с сохранениями после выхода, решает блок сохранений.
    _exits.add((game: updated, played: event.played));
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
    await _exits.close();
    await _removals.close();
    _launcher.runningIds.removeListener(_pushRunningGames);
    _launcher.dispose();
    return super.close();
  }
}
