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
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/common.dart';

import 'package:file_selector/file_selector.dart';

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
  String? _hoveredId;

  /// Над окном что-то держат. Пока это так, показываем, что сюда можно.
  bool _dragging = false;

  /// Разбор сброшенного идёт с обращениями к диску, и второй сброс поверх
  /// первого наплодил бы дубли.
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final nav = context.read<NavigationBloc>();
    final navState = context.watch<NavigationBloc>().state;
    final effects = context.select<SettingsBloc, bool>(
      (b) => b.state.libraryEffects,
    );
    final libraryIds = library.games.map((g) => g.id).toSet();
    _tileKeys.removeWhere((id, _) => !libraryIds.contains(id));

    final found = _search(library.games);
    final games = _onShelf(found, _shelf);
    if (_hoveredId != null && !games.any((g) => g.id == _hoveredId)) {
      _hoveredId = null;
    }
    final opened = library.gameById(navState.openedGameId);

    // Открытую игру могли удалить, а выбранную — отфильтровать. И то и
    // другое чинится после кадра: менять состояние во время сборки нельзя.
    _repairSelection(nav, navState, games, opened);

    if (opened != null) return _GamePage(game: opened);

    return Column(
      children: [
        _Toolbar(
          shelf: _shelf,
          counts: {
            for (final shelf in _Shelf.values)
              shelf: _onShelf(found, shelf).length,
          },
          onShelf: (value) => setState(() => _shelf = value),
          searchFocus: nav.searchFocus,
          onQuery: (value) => setState(() => _query = value),
          onScan: () => _scanFolder(context),
          onAdd: () => _addGame(context),
        ),
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) {
              setState(() => _dragging = false);
              _handleDrop(context, [for (final f in details.files) f.path]);
            },
            child: LibraryAtmosphere(
              enabled: effects,
              targetKey: () => _tileKeys[_hoveredId ?? navState.selectedGameId],
              child: Stack(
                children: [
                  Positioned.fill(
                    child: games.isEmpty
                        ? _empty(context, library.games.isEmpty)
                        : _grid(games, navState.selectedGameId, nav, effects),
                  ),
                  if (_dragging) const Positioned.fill(child: _DropOverlay()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
    bool effects,
  ) {
    final indices = {for (var i = 0; i < games.length; i++) games[i].id: i};
    return GridView.builder(
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indices[key.value] : null,
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 34),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // По ширине, а не по числу столбцов: обложка должна остаться
        // читаемой и в узком окне, и на весь экран телевизора.
        maxCrossAxisExtent: 215,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 36,
        mainAxisSpacing: 40,
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
              enabled: effects,
              child: GameCoverTile(
                key: ValueKey(game.id),
                game: game,
                selected: game.id == selectedId,
                onOpen: () => nav.add(GameOpened(game.id)),
                // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть» должна
                // работать по той игре, на которую смотришь, не заходя внутрь.
                onFocused: () => nav.add(GameSelected(game.id)),
              ),
            ),
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
  Future<void> _scanFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    final dir = await getDirectoryPath(confirmButtonText: l.scan);
    if (dir == null || !context.mounted) return;

    final added = await showScanFolderDialog(context, dir);
    if (added == null || added == 0) return;
    messenger.showSnackBar(SnackBar(content: Text(l.gamesAdded(added))));
  }

  Future<void> _addGame(BuildContext context) async {
    final nav = context.read<NavigationBloc>();
    final addedId = await showAddGameDialog(context);
    if (addedId != null && mounted) nav.add(GameSelected(addedId));
  }
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
        borderRadius: BorderRadius.circular(18),
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
  });

  final _Shelf shelf;
  final Map<_Shelf, int> counts;
  final ValueChanged<_Shelf> onShelf;
  final FocusNode searchFocus;
  final ValueChanged<String> onQuery;
  final VoidCallback onScan;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in _Shelf.values)
                    _ShelfButton(
                      label: _label(l, value),
                      count: counts[value] ?? 0,
                      active: value == shelf,
                      onTap: () => onShelf(value),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 210,
            height: 36,
            child: TextField(
              focusNode: searchFocus,
              onChanged: onQuery,
              // Enter в поиске уводит фокус в сетку — удобно и с клавиатуры,
              // и с геймпадной экранной клавиатуры.
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                hintText: l.searchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.folder_open_outlined, size: 19),
            label: Text(l.findInstalledGames),
          ),
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            tooltip: l.addGame,
          ),
        ],
      ),
    );
  }

  static String _label(L l, _Shelf shelf) => switch (shelf) {
    _Shelf.all => l.tabAll,
    _Shelf.installed => l.tabInstalled,
    _Shelf.notInstalled => l.tabNotInstalled,
  };
}

/// Полка с числом рядом — как вкладки в библиотеке Steam.
class _ShelfButton extends StatelessWidget {
  const _ShelfButton({
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
          backgroundColor: active ? colors.surfaceHigh : Colors.transparent,
          foregroundColor: active ? colors.textPrimary : colors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
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
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.outline)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
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
        Expanded(
          child: GameDetail(key: ValueKey(game.id), game: game),
        ),
      ],
    );
  }
}
