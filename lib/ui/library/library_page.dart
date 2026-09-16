import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/game_drop_target.dart';
import '../widgets/liquid_selection.dart';
import '../widgets/rise_in.dart';
import 'add_game_dialog.dart';
import 'featured_game.dart';
import 'foil_card.dart';
import 'game_cover.dart';
import 'game_page.dart';
import 'library_atmosphere.dart';
import 'library_heading.dart';
import 'primary_action.dart';
import 'scan_folder_dialog.dart';
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

  /// Выше этой высоты у кадра выбранной игры полный вид; ниже — полоса.
  static const _roomyHeight = 760.0;

  /// Ниже этой высоты кадр убирается совсем: иначе не осталось бы места
  /// самой полке.
  static const _heroHeight = 520.0;

  /// Ниже этой высоты не остаётся места и заголовку раздела.
  static const _headingHeight = 360.0;

  /// Поля сетки обложек и просвет между плитками.
  static const _gridPadding = 64.0;
  static const _gridGap = 36.0;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final nav = context.read<NavigationBloc>();
    final navState = context.watch<NavigationBloc>().state;
    final effects = context.watch<SettingsBloc>().state;
    final scale = context.select<SettingsBloc, double>(
      (b) => b.state.libraryScale,
    );
    _forgetGoneGames(library.games);

    final found = _search(library.games);
    final games = _onShelf(found, _shelf);
    final featured = _featured(games, navState.selectedGameId);
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
        final height = constraints.maxHeight;
        return LibraryAtmosphere(
          enabled: effects.libraryEffects,
          particlesEnabled: effects.particlesEnabled,
          ambientEnabled: effects.ambientEnabled,
          targetKey: () => _tileKeys[_hoveredId ?? navState.selectedGameId],
          child: Column(
            children: [
              if (height >= _headingHeight) _heading(context, scale),
              // Кадр выбранной игры не прячется там, где просто меньше
              // места: ниже 760 точек он становится полосой и уходит совсем
              // только тогда, когда иначе не осталось бы места полке.
              if (featured != null && height >= _heroHeight)
                FeaturedGame(
                  game: featured,
                  compact: height < _roomyHeight,
                  sweepEnabled:
                      effects.libraryEffects && effects.heroSweepEnabled,
                  shotsEnabled:
                      effects.libraryEffects && effects.shotsBackdropEnabled,
                  onOpen: () => nav.add(GameOpened(featured.id)),
                  onPrimary: () => dispatchPrimaryAction(context, featured),
                ),
              _toolbar(context, found, games, nav),
              Expanded(
                // Сброшенное в окно: папка становится установленной игрой,
                // `.torrent` — игрой в очереди загрузки. Magnet-ссылку сюда
                // не притащить: системы отдают её не файлом, и до приложения
                // она не доезжает. Для неё есть «Добавить игру».
                //
                // Пока открыто окно поиска, брошенное принадлежит ему.
                child: GameDropTarget(
                  enabled: !_scanning,
                  child: games.isEmpty
                      ? _empty(context, library.games.isEmpty)
                      : _measuredGrid(
                          games,
                          navState.selectedGameId,
                          nav,
                          effects,
                          scale,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Освобождает то, что осталось от игр, которых в библиотеке больше нет.
  void _forgetGoneGames(List<Game> games) {
    final alive = games.map((g) => g.id).toSet();
    _tileKeys.removeWhere((id, _) => !alive.contains(id));
    for (final id
        in _tileFocus.keys.where((id) => !alive.contains(id)).toList()) {
      _tileFocus.remove(id)!.dispose();
    }
  }

  /// Игра для крупного кадра: выбранная, а если её на полке нет — первая.
  Game? _featured(List<Game> games, String? selectedId) {
    if (games.isEmpty) return null;
    final index = games.indexWhere((game) => game.id == selectedId);
    return games[index < 0 ? 0 : index];
  }

  Widget _heading(BuildContext context, double scale) => ConceptLibraryHeading(
    scale: scale,
    onScale: (value) {
      final settings = context.read<SettingsBloc>();
      settings.add(
        SettingsChanged(settings.state.copyWith(libraryScale: value)),
      );
    },
  );

  /// Полки, поиск и клавиши «найти» и «добавить».
  Widget _toolbar(
    BuildContext context,
    List<Game> found,
    List<Game> games,
    NavigationBloc nav,
  ) => LibraryToolbar(
    shelf: _shelf,
    counts: {
      for (final shelf in Shelf.values) shelf: _onShelf(found, shelf).length,
    },
    onShelf: (value) => setState(() => _shelf = value),
    searchFocus: nav.searchFocus,
    onReturnToGames: () => _returnToGames(games, nav),
    onQuery: (value) => setState(() => _query = value),
    onScan: () => _scanFolder(context),
    onAdd: () => _addGame(context),
  );

  /// Меряет место под сетку и строит её.
  ///
  /// Ширина плитки нужна не только сетке: по ней считается шаг прокрутки,
  /// которым фокус догоняет ещё не построенную плитку.
  Widget _measuredGrid(
    List<Game> games,
    String? selectedId,
    NavigationBloc nav,
    AppSettings effects,
    double scale,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = 215 * scale;
      final room = constraints.maxWidth - _gridPadding;
      _columns = (room / (extent + _gridGap)).ceil().clamp(1, 1000);
      final tileWidth = (room - _gridGap * (_columns - 1)) / _columns;
      _rowStride = tileWidth * 1.5 + 40;
      return _grid(games, selectedId, nav, effects, extent);
    },
  );

  /// Сетка обложек: ленивая, с рамкой выбранного и всходом первого экрана.
  Widget _grid(
    List<Game> games,
    String? selectedId,
    NavigationBloc nav,
    AppSettings effects,
    double extent,
  ) {
    // Где какая игра — чтобы ленивая сетка узнавала уже построенную плитку
    // после перестановки, а не собирала её заново.
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
        itemBuilder: (context, index) => _tile(
          context,
          game: games[index],
          index: index,
          selectedId: selectedId,
          nav: nav,
          effects: effects,
        ),
      ),
    );
  }

  /// Одна плитка сетки: она же следит за курсором и всходит при появлении.
  Widget _tile(
    BuildContext context, {
    required Game game,
    required int index,
    required String? selectedId,
    required NavigationBloc nav,
    required AppSettings effects,
  }) {
    final motion = context.motion;
    final hovered = _hoveredId == game.id;

    return MouseRegion(
      key: ValueKey(game.id),
      // Наведение выбирает игру, а не только приподнимает плитку: крупный
      // кадр наверху идёт за выбором, и без этого до его клавиш было бы не
      // добраться — уведи курсор с плитки, чтобы нажать «Играть», и кадр
      // сменился бы обратно раньше, чем рука дойдёт.
      //
      // Фокус при этом не трогаем. Он у клавиатуры и геймпада, и отбирать
      // его курсором, лежащим над сеткой, значило бы уводить набор из
      // поиска. Первое же нажатие стрелки сведёт выбор обратно к
      // сфокусированной плитке: выбор идёт за фокусом, а не наоборот.
      onEnter: (_) {
        setState(() => _hoveredId = game.id);
        if (selectedId != game.id) nav.add(GameSelected(game.id));
      },
      onExit: (_) {
        if (mounted && _hoveredId == game.id) {
          setState(() => _hoveredId = null);
        }
      },
      child: RiseIn(
        enabled: effects.libraryEffects && effects.interfaceAnimationsEnabled,
        // Очередь всхода — только для первого экрана. Дальше ленивая сетка
        // строит плитки по мере прокрутки, и задержка означала бы, что
        // домотанное появляется через полсекунды после того, как человек
        // до него домотал.
        delay: index < motion.staggerLimit
            ? motion.staggerAt(index)
            : Duration.zero,
        child: AnimatedContainer(
          duration: motion.fast,
          curve: EvaporateMotion.ease,
          // Обложка приподнимается под курсором: в сетке одинаковых
          // прямоугольников это самый заметный способ показать, где рука, —
          // заметнее рамки.
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
              child: _cover(
                game,
                selectedId: selectedId,
                nav: nav,
                effects: effects,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Сама обложка и всё, что на ней живёт.
  Widget _cover(
    Game game, {
    required String? selectedId,
    required NavigationBloc nav,
    required AppSettings effects,
  }) => GameCoverTile(
    focusNode: _tileFocus.putIfAbsent(
      game.id,
      () => FocusNode(debugLabel: 'game:${game.id}'),
    ),
    key: ValueKey(game.id),
    game: game,
    selected: game.id == selectedId,
    dropsEnabled: effects.libraryEffects && effects.dropsEnabled,
    portalEnabled: effects.libraryEffects && effects.portalEnabled,
    // Рамка живёт мимо общего выключателя эффектов: она показывает, где ты
    // в сетке, а не украшает её.
    frameEnabled: effects.selectionFrameEnabled,
    onOpen: () => nav.add(GameOpened(game.id)),
    // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть» должна
    // работать по той игре, на которую смотришь, не заходя внутрь.
    onFocused: () => nav.add(GameSelected(game.id)),
  );

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
