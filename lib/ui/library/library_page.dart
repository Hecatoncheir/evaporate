import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../services/launch/drop_import.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../../models/game.dart';
import '../../models/app_settings.dart';
import '../widgets/liquid_selection.dart';
import '../widgets/rise_in.dart';
import '../theme.dart';
import '../widgets/common.dart';

import 'add_game_dialog.dart';
import 'game_cover.dart';
import 'scan_folder_dialog.dart';
import 'library_atmosphere.dart';
import 'foil_card.dart';
import '../../l10n/app_localizations.dart';
import 'drop_overlay.dart';
import 'featured_game.dart';
import 'game_page.dart';
import 'library_heading.dart';
import 'shelf.dart';
import 'toolbar.dart';

/// Библиотека: сетка вертикальных обложек, поверх неё — страница игры.
///
/// Список с подписями уступил место обложкам не ради красоты: пятьдесят
/// строк одинакового вида глазами не разбираются, а картинки узнаются
/// мгновенно и с дивана, куда это приложение и метит.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  Shelf _shelf = Shelf.all;
  final Map<String, GlobalKey> _tileKeys = {};
  final Map<String, FocusNode> _tileFocus = {};

  /// Какая игра была открыта на прошлой сборке — по её исчезновению и видно,
  /// что экран закрыли.
  String? _openedBefore;
  final _scroll = ScrollController();
  int _columns = 1;
  double _rowStride = 320;
  String? _hoveredId;

  /// Над окном что-то держат. Пока это так, показываем, что сюда можно.
  bool _dragging = false;

  /// Разбор сброшенного идёт с обращениями к диску, и второй сброс поверх
  /// первого наплодил бы дубли.
  bool _importing = false;

  /// Открыто окно поиска установленных игр.
  bool _scanning = false;

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _tileFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _returnToGames(List<Game> games, NavigationBloc nav) {
    if (games.isEmpty) {
      nav.searchFocus.unfocus();
      return;
    }
    _focusGame(nav.state.selectedGameId, games);
  }

  /// Возвращает фокус на плитку игры, домотав до неё, если нужно.
  void _focusGame(String? gameId, List<Game> games) {
    if (games.isEmpty) return;
    final selected = games.indexWhere((g) => g.id == gameId);
    final index = selected < 0 ? 0 : selected;
    final id = games[index].id;
    if (_tileFocus[id]?.context != null) {
      _tileFocus[id]!.requestFocus();
      return;
    }
    // Запомненная карточка могла остаться за пределами построенной части
    // ленивой сетки — тогда фокусу не за что зацепиться, и сперва нужно
    // до неё домотать.
    if (_scroll.hasClients) {
      _scroll.jumpTo(
        (index ~/ _columns * _rowStride).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tileFocus[id]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final nav = context.read<NavigationBloc>();
    final navState = context.watch<NavigationBloc>().state;
    final effects = context.watch<SettingsBloc>().state;
    final libraryIds = library.games.map((g) => g.id).toSet();
    final scale = context.select<SettingsBloc, double>(
      (b) => b.state.libraryScale,
    );
    _tileKeys.removeWhere((id, _) => !libraryIds.contains(id));
    for (final id
        in _tileFocus.keys.where((id) => !libraryIds.contains(id)).toList()) {
      _tileFocus.remove(id)!.dispose();
    }

    final found = _search(library.games);
    final games = _onShelf(found, _shelf);
    final selectedIndex = games.indexWhere(
      (game) => game.id == navState.selectedGameId,
    );
    final featured = games.isEmpty
        ? null
        : games[selectedIndex < 0 ? 0 : selectedIndex];
    if (_hoveredId != null && !games.any((g) => g.id == _hoveredId)) {
      _hoveredId = null;
    }
    final opened = library.gameById(navState.openedGameId);

    // Открытую игру могли удалить, а выбранную — отфильтровать. И то и
    // другое чинится после кадра: менять состояние во время сборки нельзя.
    _repairSelection(nav, navState, games, opened);
    _restoreFocusOnClose(navState, games);

    if (opened != null) return GamePage(game: opened);

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxHeight >= 760;
        final showHeading = constraints.maxHeight >= 360;
        return LibraryAtmosphere(
          enabled: effects.libraryEffects,
          particlesEnabled: effects.particlesEnabled,
          ambientEnabled: effects.ambientEnabled,
          targetKey: () => _tileKeys[_hoveredId ?? navState.selectedGameId],
          child: Column(
            children: [
              if (showHeading)
                ConceptLibraryHeading(
                  compact: !roomy,
                  scale: scale,
                  onScale: (value) {
                    final settings = context.read<SettingsBloc>();
                    settings.add(
                      SettingsChanged(
                        settings.state.copyWith(libraryScale: value),
                      ),
                    );
                  },
                ),
              if (featured != null && roomy)
                FeaturedGame(
                  game: featured,
                  sweepEnabled:
                      effects.libraryEffects && effects.heroSweepEnabled,
                  onOpen: () => nav.add(GameOpened(featured.id)),
                  onPrimary: () => _primaryGameAction(context, featured),
                ),
              LibraryToolbar(
                shelf: _shelf,
                counts: {
                  for (final shelf in Shelf.values)
                    shelf: _onShelf(found, shelf).length,
                },
                onShelf: (value) => setState(() => _shelf = value),
                searchFocus: nav.searchFocus,
                onReturnToGames: () => _returnToGames(games, nav),
                onQuery: (value) => setState(() => _query = value),
                onScan: () => _scanFolder(context),
                onAdd: () => _addGame(context),
              ),
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) {
                    if (!_scanning) setState(() => _dragging = true);
                  },
                  onDragExited: (_) => setState(() => _dragging = false),
                  onDragDone: (details) {
                    setState(() => _dragging = false);
                    // Пока открыто окно поиска, брошенное принадлежит ему.
                    if (_scanning) return;
                    _handleDrop(context, [
                      for (final f in details.files) f.path,
                    ]);
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: games.isEmpty
                            ? _empty(context, library.games.isEmpty)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final extent = 215 * scale;
                                  _columns =
                                      ((constraints.maxWidth - 64) /
                                              (extent + 36))
                                          .ceil()
                                          .clamp(1, 1000);
                                  final tileWidth =
                                      (constraints.maxWidth -
                                          64 -
                                          36 * (_columns - 1)) /
                                      _columns;
                                  _rowStride = tileWidth * 1.5 + 40;
                                  return _grid(
                                    games,
                                    navState.selectedGameId,
                                    nav,
                                    effects,
                                    extent,
                                  );
                                },
                              ),
                      ),
                      if (_dragging)
                        const Positioned.fill(child: DropOverlay()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _primaryGameAction(BuildContext context, Game game) {
    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();
    switch (game.status) {
      case GameStatus.running:
        library.add(GameStopRequested(game));
      case GameStatus.downloading:
        downloads.add(DownloadPauseRequested(game));
      case GameStatus.paused:
        downloads.add(DownloadResumeRequested(game));
      case GameStatus.installed:
        if (game.canLaunch) library.add(GameLaunchRequested(game));
      case GameStatus.notInstalled:
      case GameStatus.error:
        final source = game.source;
        if (source != null && source.kind != GameSourceKind.localFolder) {
          downloads.add(DownloadRequested(game: game, source: source));
        }
    }
  }

  /// Сброшенное в окно: папка становится установленной игрой, `.torrent` —
  /// игрой в очереди загрузки.
  ///
  /// Magnet-ссылку сюда не притащить: системы отдают её не файлом, и до
  /// приложения она не доезжает. Для неё есть «Добавить игру».
  Future<void> _handleDrop(BuildContext context, List<String> paths) async {
    if (_importing || paths.isEmpty) return;
    setState(() => _importing = true);

    // До первого await: после него context трогать нельзя.
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();
    final nav = context.read<NavigationBloc>();

    try {
      final candidates = await DropImport.inspect(paths);
      var added = 0;
      var queued = 0;
      String? lastId;

      for (final candidate in candidates) {
        if (candidate.kind == DropKind.unsupported) continue;

        final id = const Uuid().v4();
        library.add(
          GameAdded(
            id: id,
            title: candidate.title,
            source: candidate.source,
            installDir: candidate.kind == DropKind.folder
                ? candidate.path
                : null,
            executablePath: candidate.executablePath,
            status: candidate.kind == DropKind.folder
                ? GameStatus.installed
                : GameStatus.notInstalled,
          ),
        );
        added++;
        lastId = id;

        if (candidate.kind == DropKind.torrent) {
          if (await _startDownload(library, downloads, id, candidate.source)) {
            queued++;
          }
        }
      }

      if (added == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l.dropNothing)));
        return;
      }
      if (lastId != null) nav.add(GameSelected(lastId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            queued == 0
                ? l.dropAdded(added)
                : '${l.dropAdded(added)}, ${l.dropQueued(queued)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Событие добавления обрабатывается асинхронно, поэтому перед запуском
  /// загрузки дожидаемся, пока игра действительно появится в состоянии.
  ///
  /// Возвращает `false`, когда движок не готов: игра всё равно добавлена,
  /// и загрузку можно запустить руками позже.
  Future<bool> _startDownload(
    LibraryBloc library,
    DownloadsBloc downloads,
    String id,
    GameSource source,
  ) async {
    if (!downloads.state.engine.isReady) return false;
    var game = library.state.gameById(id);
    game ??= (await library.stream.firstWhere(
      (state) => state.gameById(id) != null,
    )).gameById(id);
    if (game == null) return false;
    downloads.add(DownloadRequested(game: game, source: source));
    return true;
  }

  Widget _grid(
    List<Game> games,
    String? selectedId,
    NavigationBloc nav,
    AppSettings effects,
    double extent,
  ) {
    final indices = {for (var i = 0; i < games.length; i++) games[i].id: i};
    return LiquidSelection(
      key: const ValueKey('grid-liquid'),
      targetKey: () => _tileKeys[_hoveredId ?? selectedId],
      enabled: effects.libraryEffects && effects.liquidSelectionEnabled,
      color: context.colors.selection,
      radius: EvaporateTheme.radiusPanel,
      padding: const EdgeInsets.all(7),
      child: GridView.builder(
        controller: _scroll,
        findChildIndexCallback: (key) =>
            key is ValueKey<String> ? indices[key.value] : null,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          // По ширине, а не по числу столбцов: обложка должна остаться
          // читаемой и в узком окне, и на весь экран телевизора.
          maxCrossAxisExtent: extent,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 28,
          mainAxisSpacing: 32,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          final motion = context.motion;
          final hovered = _hoveredId == game.id;
          return MouseRegion(
            key: ValueKey(game.id),
            onEnter: (_) => setState(() => _hoveredId = game.id),
            onExit: (_) {
              if (mounted && _hoveredId == game.id) {
                setState(() => _hoveredId = null);
              }
            },
            child: RiseIn(
              enabled:
                  effects.libraryEffects && effects.interfaceAnimationsEnabled,
              // Очередь всхода — только для первого экрана. Дальше ленивая
              // сетка строит плитки по мере прокрутки, и задержка означала
              // бы, что домотанное появляется через полсекунды после того,
              // как человек до него домотал.
              delay: index < motion.staggerLimit
                  ? motion.staggerAt(index)
                  : Duration.zero,
              child: AnimatedContainer(
                duration: motion.fast,
                curve: EvaporateMotion.ease,
                // Обложка приподнимается под курсором: в сетке одинаковых
                // прямоугольников это самый заметный способ показать, где
                // рука, — заметнее рамки.
                transform: Matrix4.translationValues(0, hovered ? -7 : 0, 0),
                child: KeyedSubtree(
                  key: _tileKeys.putIfAbsent(
                    game.id,
                    () => GlobalKey(debugLabel: game.id),
                  ),
                  child: FoilCard(
                    active: (_hoveredId ?? selectedId) == game.id,
                    enabled: effects.libraryEffects,
                    foilEnabled: effects.foilEnabled,
                    tiltEnabled: effects.cardTiltEnabled,
                    distortionEnabled: effects.liquidDistortionEnabled,
                    child: GameCoverTile(
                      focusNode: _tileFocus.putIfAbsent(
                        game.id,
                        () => FocusNode(debugLabel: 'game:${game.id}'),
                      ),
                      key: ValueKey(game.id),
                      game: game,
                      selected: game.id == selectedId,
                      dropsEnabled:
                          effects.libraryEffects && effects.dropsEnabled,
                      portalEnabled:
                          effects.libraryEffects && effects.portalEnabled,
                      // Рамка живёт мимо общего выключателя эффектов: она
                      // показывает, где ты в сетке, а не украшает её.
                      frameEnabled: effects.selectionFrameEnabled,
                      onOpen: () => nav.add(GameOpened(game.id)),
                      // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть» должна
                      // работать по той игре, на которую смотришь, не заходя внутрь.
                      onFocused: () => nav.add(GameSelected(game.id)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Возвращает выбор в осмысленное состояние, если он повис в воздухе.
  void _repairSelection(
    NavigationBloc nav,
    NavigationState state,
    List<Game> games,
    Game? opened,
  ) {
    final selectionLost =
        games.isNotEmpty && !games.any((g) => g.id == state.selectedGameId);
    final openingLost = state.openedGameId != null && opened == null;
    if (!selectionLost && !openingLost) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (openingLost) nav.add(const GameOpened(null));
      if (selectionLost) nav.add(GameSelected(games.first.id));
    });
  }

  /// Возвращает фокус на плитку, с экрана которой ушли.
  ///
  /// Экран игры показывается вместо сетки, и при закрытии его виджеты
  /// исчезают вместе с фокусом. Опереться фокусу становится не на что, и он
  /// уезжает в боковую панель — а человек ждёт, что вернётся туда, откуда
  /// уходил, тем более что игра там по-прежнему выбрана.
  void _restoreFocusOnClose(NavigationState state, List<Game> games) {
    final opened = state.openedGameId;
    final before = _openedBefore;
    _openedBefore = opened;
    if (before == null || opened != null) return;

    // После кадра: сетка на этот момент ещё не построена, и плитки, на
    // которую надо встать, в дереве нет.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusGame(state.selectedGameId ?? before, games);
    });
  }

  List<Game> _search(List<Game> games) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...games]
        : games.where((g) => g.title.toLowerCase().contains(query)).toList();
    filtered.sort((a, b) {
      // Сначала то, что происходит прямо сейчас, потом недавно запущенное.
      final byActivity = _activityRank(a).compareTo(_activityRank(b));
      if (byActivity != 0) return byActivity;
      final aPlayed = a.lastPlayed;
      final bPlayed = b.lastPlayed;
      if (aPlayed != null && bPlayed != null) return bPlayed.compareTo(aPlayed);
      if (aPlayed != null) return -1;
      if (bPlayed != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  static List<Game> _onShelf(List<Game> games, Shelf shelf) => switch (shelf) {
    Shelf.all => games,
    // Запущенная игра установлена по определению, качающаяся — ещё нет.
    Shelf.installed =>
      games
          .where(
            (g) =>
                g.status == GameStatus.installed ||
                g.status == GameStatus.running,
          )
          .toList(),
    Shelf.notInstalled =>
      games
          .where(
            (g) =>
                g.status != GameStatus.installed &&
                g.status != GameStatus.running,
          )
          .toList(),
  };

  static int _activityRank(Game game) => switch (game.status) {
    GameStatus.running => 0,
    GameStatus.downloading => 1,
    GameStatus.paused => 2,
    GameStatus.error => 3,
    GameStatus.installed => 4,
    GameStatus.notInstalled => 5,
  };

  Widget _empty(BuildContext context, bool libraryIsEmpty) {
    if (!libraryIsEmpty) {
      return EmptyState(
        icon: Icons.videogame_asset_outlined,
        title: L.of(context).nothingFound,
      );
    }
    return EmptyState(
      icon: Icons.videogame_asset_outlined,
      title: L.of(context).libraryEmpty,
      description: L.of(context).libraryEmptyNote,
      action: FilledButton.icon(
        onPressed: () => _addGame(context),
        icon: const Icon(Icons.add),
        label: Text(L.of(context).addGame),
      ),
    );
  }

  /// Добавление по одной терпимо для трёх игр и мучительно для сорока.
  ///
  /// Поиск начинается сразу: известные места — библиотеки Steam, папки
  /// лончеров, подключённые тома — осматриваются, не дожидаясь, пока
  /// человек что-нибудь выберет. Сузить его до одной папки можно прямо в
  /// окне поиска: бросить её туда или выбрать в системном окне, которое
  /// откроется по нажатию. Само оно не открывается — человек нажал «найти
  /// игры», а не «выбери папку».
  Future<void> _scanFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    final library = context.read<LibraryBloc>();
    final settings = context.read<SettingsBloc>();

    final session = ScanSession(
      existingDirs: LibraryScanner.installedDirs(library.state.games),
      installDir: settings.state.installDir,
    );
    unawaited(session.scanKnownRoots());

    // Пока окно поиска открыто, сетка броски не ловит: папку в нём бросают
    // ради сужения поиска, а не чтобы добавить её как одну игру.
    setState(() => _scanning = true);
    try {
      final added = await showScanFolderDialog(context, session);
      if (added == null || added == 0 || !mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.gamesAdded(added))));
    } finally {
      session.dispose();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _addGame(BuildContext context) async {
    final nav = context.read<NavigationBloc>();
    final addedId = await showAddGameDialog(context);
    if (addedId != null && mounted) nav.add(GameSelected(addedId));
  }
}
