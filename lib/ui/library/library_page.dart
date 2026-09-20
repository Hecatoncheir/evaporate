import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/library_view/library_view_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/shelf.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import 'add_game_dialog.dart';
import 'game_page.dart';
import 'library_body.dart';
import 'library_grid_controller.dart';
import 'scan_folder_dialog.dart';

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
  /// Запрос и полка — свой блок экрана: в `State` остаются только
  /// ресурсы, то есть наведение, фокус и прокрутка.
  final _view = LibraryViewBloc();
  final _grid = LibraryGridController();

  /// Фокус поля поиска.
  ///
  /// Живёт здесь, а не в `NavigationBloc`: `FocusNode` — ресурс с
  /// жизненным циклом виджета, и блок, который его заводил, обязан был
  /// знать, что поле поиска вообще существует.
  final _searchFocus = FocusNode(debugLabel: 'search');
  late final StreamSubscription<LibraryView> _viewChanges;

  /// Какая игра была открыта на прошлой сборке — по её исчезновению и видно,
  /// что экран закрыли.
  String? _openedBefore;

  /// Открыто окно поиска установленных игр.
  bool _scanning = false;

  /// Сколько раз просили фокус в поиск на прошлой сборке.
  int _searchFocusBefore = 0;

  @override
  void initState() {
    super.initState();
    // Наведение меняет и крупный кадр наверху, и свет вокруг сетки:
    // перестраивается вся страница, а не одна плитка.
    _grid.addListener(_onGridChanged);
    // Блок свой, и провайдера над страницей у него нет: подписываемся
    // прямо здесь — так же, как на наведение в сетке.
    _viewChanges = _view.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onGridChanged() => setState(() {});

  @override
  void dispose() {
    unawaited(_viewChanges.cancel());
    unawaited(_view.close());
    _grid
      ..removeListener(_onGridChanged)
      ..dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _returnToGames(List<Game> games, NavigationBloc nav) {
    if (games.isEmpty) {
      _searchFocus.unfocus();
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

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    final navState = context.watch<NavigationBloc>().state;
    // Подписываемся на сами игры, а не на всё состояние библиотеки: в нём
    // живут ещё и занятость с ходом поиска путей, и сетка обложек
    // перестраивалась на каждый их чих.
    final all = context.select<LibraryBloc, List<Game>>((b) => b.state.games);
    final opened = context.select<LibraryBloc, Game?>(
      (b) => b.state.gameById(navState.openedGameId),
    );
    final effects = context.watch<SettingsBloc>().state;
    final scale = context.select<SettingsBloc, double>(
      (b) => b.state.libraryScale,
    );
    _grid.forgetGone(all.map((game) => game.id).toSet());

    final view = _view.state;
    final found = view.found(all);
    final games = gamesOnShelf(found, view.shelf);

    // Открытую игру могли удалить, а выбранную — отфильтровать. И то и
    // другое чинится после кадра: менять состояние во время сборки нельзя.
    _repairSelection(nav, navState, games, opened);
    _restoreFocusOnClose(navState, games);
    _grabSearchFocus(navState);

    if (opened != null) return GamePage(game: opened);

    return LibraryBody(
      grid: _grid,
      games: games,
      found: found,
      libraryIsEmpty: all.isEmpty,
      shelf: view.shelf,
      selectedId: navState.selectedGameId,
      effects: effects,
      scale: scale,
      scanning: _scanning,
      searchFocus: _searchFocus,
      onShelf: (value) => _view.add(LibraryShelfSelected(value)),
      onQuery: (value) => _view.add(LibraryQueryChanged(value)),
      onReturnToGames: () => _returnToGames(games, nav),
      onScan: () => _scanFolder(context),
      onAdd: () => _addGame(context),
      onSelect: (id) => nav.add(GameSelected(id)),
      onOpen: (id) => nav.add(GameOpened(id)),
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

  /// Уводит фокус в поиск, если о том просили.
  ///
  /// Блок просьбу только записывает — счётчиком, как `Notice.seq`, иначе
  /// две просьбы подряд не отличались бы одна от другой. Ставит фокус тот,
  /// кто владеет полем; и после кадра, потому что просьба приходит вместе
  /// с переключением на библиотеку, а поля поиска в этот миг ещё нет.
  void _grabSearchFocus(NavigationState state) {
    final before = _searchFocusBefore;
    _searchFocusBefore = state.searchFocusSeq;
    if (state.searchFocusSeq == before) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
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
