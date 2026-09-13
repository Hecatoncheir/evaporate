import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
import '../../input/input_scope.dart';
import '../widgets/scale_control.dart';
import '../widgets/liquid_selection.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/spatial_surface.dart';

import 'add_game_dialog.dart';
import 'game_cover.dart';
import 'scan_folder_dialog.dart';
import 'game_detail.dart';
import 'library_atmosphere.dart';
import 'foil_card.dart';
import '../../l10n/app_localizations.dart';

/// Вкладки поверх сетки. Раскладывают библиотеку без остатка: игра ровно в
/// одной из двух, и суммы сходятся с «Все».
enum _Shelf { all, installed, notInstalled }

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
  _Shelf _shelf = _Shelf.all;
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
    if (_hoveredId != null && !games.any((g) => g.id == _hoveredId)) {
      _hoveredId = null;
    }
    final opened = library.gameById(navState.openedGameId);

    // Открытую игру могли удалить, а выбранную — отфильтровать. И то и
    // другое чинится после кадра: менять состояние во время сборки нельзя.
    _repairSelection(nav, navState, games, opened);
    _restoreFocusOnClose(navState, games);

    if (opened != null) return _GamePage(game: opened);

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxHeight >= 760;
        final showHeading = constraints.maxHeight >= 360;
        return Column(
          children: [
            if (showHeading)
              _ConceptLibraryHeading(
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
            if (games.isNotEmpty && roomy)
              _FeaturedGame(
                game: games.first,
                onOpen: () => nav.add(GameOpened(games.first.id)),
                onPrimary: () => _primaryGameAction(context, games.first),
              ),
            _Toolbar(
              shelf: _shelf,
              counts: {
                for (final shelf in _Shelf.values)
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
                  _handleDrop(context, [for (final f in details.files) f.path]);
                },
                child: LibraryAtmosphere(
                  enabled: effects.libraryEffects,
                  particlesEnabled: effects.particlesEnabled,
                  ambientEnabled: effects.ambientEnabled,
                  targetKey: () =>
                      _tileKeys[_hoveredId ?? navState.selectedGameId],
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
                        const Positioned.fill(child: _DropOverlay()),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      radius: 12,
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
          return MouseRegion(
            key: ValueKey(game.id),
            onEnter: (_) => setState(() => _hoveredId = game.id),
            onExit: (_) {
              if (mounted && _hoveredId == game.id) {
                setState(() => _hoveredId = null);
              }
            },
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
                  dropsEnabled: effects.libraryEffects && effects.dropsEnabled,
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

  static List<Game> _onShelf(List<Game> games, _Shelf shelf) => switch (shelf) {
    _Shelf.all => games,
    // Запущенная игра установлена по определению, качающаяся — ещё нет.
    _Shelf.installed =>
      games
          .where(
            (g) =>
                g.status == GameStatus.installed ||
                g.status == GameStatus.running,
          )
          .toList(),
    _Shelf.notInstalled =>
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

class _ConceptLibraryHeading extends StatelessWidget {
  const _ConceptLibraryHeading({
    required this.compact,
    required this.scale,
    required this.onScale,
  });

  final bool compact;
  final double scale;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(28, compact ? 18 : 24, 28, compact ? 4 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.of(context).conceptLibraryLabel,
                style: TextStyle(
                  color: context.colors.primary,
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                compact
                    ? L.of(context).conceptLibraryHeadlineCompact
                    : L.of(context).conceptLibraryHeadline,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontFamily: EvaporateTheme.displayFontFamily,
                  fontSize: compact ? 25 : 38,
                  height: 0.92,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? -1 : -2.1,
                ),
              ),
            ],
          ),
        ),
        if (compact) ...[
          const SizedBox(width: 16),
          ScaleControl(
            key: const ValueKey('library-scale'),
            label: L.of(context).coverScale,
            value: scale,
            min: AppSettings.minLibraryScale,
            max: AppSettings.maxLibraryScale,
            step: 0.25,
            onChanged: onScale,
          ),
        ],
        if (!compact) ...[
          const SizedBox(width: 32),
          Container(
            width: 310,
            padding: const EdgeInsets.only(left: 22),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.48),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).conceptLibraryDescription,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                ScaleControl(
                  key: const ValueKey('library-scale'),
                  label: L.of(context).coverScale,
                  value: scale,
                  min: AppSettings.minLibraryScale,
                  max: AppSettings.maxLibraryScale,
                  step: 0.25,
                  onChanged: onScale,
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _FeaturedGame extends StatelessWidget {
  const _FeaturedGame({
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final playable = game.status != GameStatus.installed || game.canLaunch;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: SizedBox(
        height: 238,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/branding/orbit_fall_hero.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0.2, 0.46),
                filterQuality: FilterQuality.medium,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.heroShadeStrong,
                      AppColors.heroShadeMiddle,
                      AppColors.heroShadeClear,
                    ],
                    stops: [0, 0.48, 0.82],
                  ),
                ),
              ),
              Positioned(
                left: 26,
                top: 22,
                bottom: 22,
                width: 430,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L
                          .of(context)
                          .conceptFeaturedContinue(
                            game.lastPlayed == null
                                ? L.of(context).featuredReady
                                : L.of(context).featuredRecent,
                          ),
                      style: const TextStyle(
                        color: AppColors.heroEyebrow,
                        fontFamily: EvaporateTheme.monoFontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      game.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.coverText,
                        fontFamily: EvaporateTheme.displayFontFamily,
                        fontSize: 38,
                        height: 0.88,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      game.description?.trim().isNotEmpty == true
                          ? game.description!
                          : L.of(context).featuredFallbackDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.heroBody,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        LauncherActionButton(
                          onPressed: playable ? onPrimary : null,
                          icon:
                              game.status == GameStatus.notInstalled ||
                                  game.status == GameStatus.error
                              ? Icons.download_rounded
                              : Icons.play_arrow_rounded,
                          label: _primaryLabel(context, game),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onOpen,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.coverText,
                            side: BorderSide(
                              color: AppColors.coverText.withValues(
                                alpha: 0.38,
                              ),
                            ),
                            minimumSize: const Size(112, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(L.of(context).openGame),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 18,
                child: Container(
                  width: 198,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.heroPanel,
                    border: Border.all(color: AppColors.coverProgressTrack),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.of(context).inGame,
                        style: TextStyle(
                          color: AppColors.coverText.withValues(alpha: 0.6),
                          fontFamily: EvaporateTheme.monoFontFamily,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDurationLabel(L.of(context), game.playtime),
                        style: const TextStyle(
                          color: AppColors.coverText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _primaryLabel(BuildContext context, Game game) =>
      switch (game.status) {
        GameStatus.running => L.of(context).stop,
        GameStatus.downloading => L.of(context).pause,
        GameStatus.paused => L.of(context).resume,
        GameStatus.installed => L.of(context).play,
        GameStatus.notInstalled || GameStatus.error => L.of(context).download,
      };
}

/// Подсказка поверх сетки, пока над окном что-то держат.
///
/// Молчаливый приёмник — худший из возможных: пользователь не знает ни что
/// сюда можно, ни что случится, и проверяет это на своей библиотеке.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return IgnorePointer(
      child: Container(
        color: context.colors.background.withValues(alpha: 0.86),
        padding: const EdgeInsets.all(24),
        child: DottedBorderBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 44,
                color: context.colors.accent,
              ),
              const SizedBox(height: 14),
              Text(
                l.dropRelease,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${l.dropHintFolder} • ${l.dropHintTorrent}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Рамка, показывающая границу приёмника.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.accent, width: 2),
      ),
      child: Center(child: child),
    );
  }
}

/// Верхняя строка: полки с числами, поиск и добавление.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.shelf,
    required this.counts,
    required this.onShelf,
    required this.searchFocus,
    required this.onQuery,
    required this.onScan,
    required this.onAdd,
    required this.onReturnToGames,
  });

  final _Shelf shelf;
  final Map<_Shelf, int> counts;
  final ValueChanged<_Shelf> onShelf;
  final FocusNode searchFocus;
  final ValueChanged<String> onQuery;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final filters = KeyedSubtree(
      key: const ValueKey('library-filter-group'),
      child: _ShelfTabs(shelf: shelf, counts: counts, onShelf: onShelf),
    );
    final actions = KeyedSubtree(
      key: const ValueKey('library-actions-group'),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onScan,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.folder_open_outlined, size: 19),
            label: Text(l.findInstalledGames),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.add, size: 19),
            label: Text(l.addGame),
          ),
        ],
      ),
    );
    final search = SizedBox(
      key: const ValueKey('library-search'),
      width: 144,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.railBackground.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colors.textPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Actions(
            actions: {
              ReturnToLibraryIntent: CallbackAction<ReturnToLibraryIntent>(
                onInvoke: (_) {
                  onReturnToGames();
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.escape):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.enter):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    ReturnToLibraryIntent(),
              },
              child: TextField(
                focusNode: searchFocus,
                onChanged: onQuery,
                onSubmitted: (_) => onReturnToGames(),
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: GlassSurface(
        radius: 12,
        opacity: context.colors.isDark ? 0.72 : 0.84,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1340) {
              return Row(
                children: [
                  filters,
                  const Spacer(),
                  actions,
                  const Spacer(),
                  search,
                ],
              );
            }
            if (constraints.maxWidth >= 760) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      filters,
                      const SizedBox(width: 16),
                      Expanded(child: search),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.center, child: actions),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.centerLeft, child: filters),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: search),
                const SizedBox(height: 8),
                Align(alignment: Alignment.center, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShelfTabs extends StatefulWidget {
  const _ShelfTabs({
    required this.shelf,
    required this.counts,
    required this.onShelf,
  });
  final _Shelf shelf;
  final Map<_Shelf, int> counts;
  final ValueChanged<_Shelf> onShelf;

  @override
  State<_ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends State<_ShelfTabs> {
  final _targets = {for (final shelf in _Shelf.values) shelf: GlobalKey()};

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.railBackground.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: context.colors.textPrimary.withValues(alpha: 0.1),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: LiquidSelection(
        key: const ValueKey('shelf-liquid'),
        targetKey: () => _targets[widget.shelf],
        color: context.colors.selection,
        radius: 8,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in _Shelf.values)
              _ShelfButton(
                key: _targets[value],
                label: _label(L.of(context), value),
                count: widget.counts[value] ?? 0,
                active: value == widget.shelf,
                onTap: () => widget.onShelf(value),
              ),
          ],
        ),
      ),
    ),
  );

  static String _label(L l, _Shelf shelf) => switch (shelf) {
    _Shelf.all => l.tabAll,
    _Shelf.installed => l.tabInstalled,
    _Shelf.notInstalled => l.tabNotInstalled,
  };
}

/// Полка с числом рядом — как вкладки в библиотеке Steam.
class _ShelfButton extends StatelessWidget {
  const _ShelfButton({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: active ? colors.onSelection : colors.textSecondary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: LiquidSelectionInk(
          normalColor: colors.textSecondary,
          selectedColor: colors.onSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Страница игры поверх сетки: заголовок с возвратом и карточка под ним.
class _GamePage extends StatelessWidget {
  const _GamePage({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: GlassSurface(
            radius: 12,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => nav.add(const GameOpened(null)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(L.of(context).backToLibrary),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GameDetail(key: ValueKey(game.id), game: game),
        ),
      ],
    );
  }
}
