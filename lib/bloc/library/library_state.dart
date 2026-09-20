part of 'library_bloc.dart';

/// Игры и то, что с ними сейчас происходит.
///
/// Снимки сохранений живут не здесь, а в `SavesState`: они меняются своим
/// чередом, а страница библиотеки подписана на это состояние целиком — и
/// перестраивала сетку обложек на каждый снятый снимок.
class LibraryState extends Equatable implements BusyState<LibraryState> {
  const LibraryState({
    this.games = const [],
    this.runningIds = const {},
    this.busy = const {},
    this.loaded = false,
    this.notice,
    this.savePathsProgress,
  });

  final List<Game> games;

  /// Игры, процесс которых сейчас запущен.
  final Set<String> runningIds;

  /// Ключи выполняющихся операций — виджетам не нужен собственный `_busy`.
  @override
  final Set<String> busy;
  final bool loaded;
  @override
  final Notice? notice;

  /// Ход подготовки базы путей, пока она качается и разбирается.
  final CatalogProgress? savePathsProgress;

  Game? gameById(String? id) {
    if (id == null) return null;
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }

  /// Игра, которую качает задача с этим id.
  ///
  /// Сверяется и по id задачи, и по infohash. У нынешнего движка id задачи
  /// и есть infohash раздачи, но в `downloadTaskId` у игры может лежать id,
  /// записанный прежним движком, — тогда узнать её можно только по
  /// infohash.
  Game? gameForTask(String taskId) {
    for (final game in games) {
      if (game.downloadTaskId == taskId || game.infoHash == taskId) {
        return game;
      }
    }
    return null;
  }

  bool isBusy(String key) => busy.contains(key);

  bool isRunning(String gameId) => runningIds.contains(gameId);

  LibraryState copyWith({
    List<Game>? games,
    Set<String>? runningIds,
    Set<String>? busy,
    bool? loaded,
    Object? notice = _unset,
    Object? savePathsProgress = _unset,
  }) {
    return LibraryState(
      games: games ?? this.games,
      runningIds: runningIds ?? this.runningIds,
      busy: busy ?? this.busy,
      loaded: loaded ?? this.loaded,
      notice: notice == _unset ? this.notice : notice as Notice?,
      savePathsProgress: savePathsProgress == _unset
          ? this.savePathsProgress
          : savePathsProgress as CatalogProgress?,
    );
  }

  /// Игры, которые можно поставить в очередь: есть откуда качать, ещё не
  /// установлены и не качаются прямо сейчас.
  ///
  /// Здесь, а не в `build` списка источников: отбор идёт по всей
  /// библиотеке и на каждую пересборку страницы загрузок.
  List<Game> downloadable(Iterable<String> busyIds) {
    final busy = busyIds.toSet();
    return [
      for (final game in games)
        if (_canQueue(game, busy)) game,
    ];
  }

  static bool _canQueue(Game game, Set<String> busy) {
    final source = game.source;
    if (source == null || source.kind == GameSourceKind.localFolder) {
      return false;
    }
    if (game.isInstalled) return false;
    final hash = game.infoHash;
    return hash == null || !busy.contains(hash);
  }

  @override
  LibraryState withBusy(Set<String> busy, {Notice? notice}) =>
      copyWith(busy: busy, notice: notice ?? this.notice);

  @override
  List<Object?> get props => [
    games,
    runningIds,
    busy,
    loaded,
    savePathsProgress,
    notice,
  ];

  static const _unset = Object();
}
