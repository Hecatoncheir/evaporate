import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../widgets/game_drop_target.dart';
import 'add_game_dialog.dart';
import 'effects/library_atmosphere.dart';
import 'game_page.dart';
import 'library_empty_state.dart';
import 'library_featured_slot.dart';
import 'library_grid.dart';
import 'library_grid_controller.dart';
import 'library_heading_bar.dart';
import 'library_shelf_bar.dart';
import 'scan_folder_dialog.dart';
import 'shelf.dart';

/// Библиотека: сетка вертикальных обложек, поверх неё — страница игры.
///
/// Список с подписями уступил место обложкам не ради красоты: пятьдесят
/// строк одинакового вида глазами не разбираются, а картинки узнаются
/// мгновенно и с дивана, куда это приложение и метит.
/// Сброшенное в окно библиотеки: папка становится установленной игрой,
/// `.torrent` — игрой в очереди загрузки. Magnet-ссылку сюда не притащить:
/// системы отдают её не файлом, и до приложения она не доезжает — для неё
/// есть «Добавить игру». Пока открыто окно поиска установленных игр,
/// брошенное принадлежит ему.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  Shelf _shelf = Shelf.all;
  final _grid = LibraryGridController();

  /// Какая игра была открыта на прошлой сборке — по её исчезновению и видно,
  /// что экран закрыли.
  String? _openedBefore;

  /// Открыто окно поиска установленных игр.
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    // Наведение меняет и крупный кадр наверху, и свет вокруг сетки:
    // перестраивается вся страница, а не одна плитка.
    _grid.addListener(_onGridChanged);
  }

  void _onGridChanged() => setState(() {});

  @override
  void dispose() {
    _grid
      ..removeListener(_onGridChanged)
      ..dispose();
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
    if (_grid.isBuilt(id)) {
      _grid.requestFocus(id);
      return;
    }
    // Запомненная карточка могла остаться за пределами построенной части
    // ленивой сетки — тогда фокусу не за что зацепиться, и сперва нужно
    // до неё домотать.
    _grid.scrollTo(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _grid.requestFocus(id);
    });
  }

  /// Ниже этой высоты не остаётся места и заголовку раздела.
  static const _headingHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final nav = context.read<NavigationBloc>();
    final navState = context.watch<NavigationBloc>().state;
    final effects = context.watch<SettingsBloc>().state;
    final scale = context.select<SettingsBloc, double>(
      (b) => b.state.libraryScale,
    );
    _grid.forgetGone(library.games.map((g) => g.id).toSet());

    final found = _search(library.games);
    final games = gamesOnShelf(found, _shelf);
    final opened = library.gameById(navState.openedGameId);

    // Открытую игру могли удалить, а выбранную — отфильтровать. И то и
    // другое чинится после кадра: менять состояние во время сборки нельзя.
    _repairSelection(nav, navState, games, opened);
    _restoreFocusOnClose(navState, games);

    if (opened != null) return GamePage(game: opened);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return LibraryAtmosphere(
          enabled: effects.libraryEffects,
          particlesEnabled: effects.particlesEnabled,
          ambientEnabled: effects.ambientEnabled,
          targetKey: () => _grid.targetKey(navState.selectedGameId),
          child: Column(
            children: [
              if (height >= _headingHeight) const LibraryHeadingBar(),
              LibraryFeaturedSlot(
                games: games,
                selectedId: navState.selectedGameId,
                effects: effects,
                height: height,
              ),
              LibraryShelfBar(
                shelf: _shelf,
                found: found,
                searchFocus: nav.searchFocus,
                onShelf: (value) => setState(() => _shelf = value),
                onQuery: (value) => setState(() => _query = value),
                onReturnToGames: () => _returnToGames(games, nav),
                onScan: () => _scanFolder(context),
                onAdd: () => _addGame(context),
              ),
              Expanded(
                child: GameDropTarget(
                  enabled: !_scanning,
                  child: games.isEmpty
                      ? LibraryEmptyState(
                          libraryIsEmpty: library.games.isEmpty,
                          onAdd: () => _addGame(context),
                        )
                      : LibraryGrid(
                          controller: _grid,
                          games: games,
                          selectedId: navState.selectedGameId,
                          effects: effects,
                          scale: scale,
                          onSelect: (id) => nav.add(GameSelected(id)),
                          onOpen: (id) => nav.add(GameOpened(id)),
                        ),
                ),
              ),
            ],
          ),
        );
      },
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

  static int _activityRank(Game game) => switch (game.status) {
    GameStatus.running => 0,
    GameStatus.downloading => 1,
    GameStatus.paused => 2,
    GameStatus.error => 3,
    GameStatus.installed => 4,
    GameStatus.notInstalled => 5,
  };

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
