part of 'library_bloc.dart';

/// Что завелось из брошенного в окно.
///
/// Публикуется наружу, а не решается здесь: поставить раздачу в очередь —
/// дело загрузок, а подсветить новую игру — дело навигации. Зависимость
/// идёт в одну сторону, и передать им событие напрямую нечем.
class DroppedGames {
  const DroppedGames({required this.games, required this.select});

  final List<Game> games;

  /// Подсветить последнюю в сетке библиотеки. С экрана загрузок — нет:
  /// человек оставил выбор в соседнем разделе, а видит сейчас очередь.
  final bool select;
}

/// Сброшенные в окно файлы: разбор, заведение игр и рассказ о случившемся.
extension _LibraryDrops on LibraryBloc {
  /// Разбирает брошенное и заводит из него игры.
  ///
  /// Раньше это жило в приёмнике: со своим флагом занятости, ожиданием
  /// чужого состояния и `SnackBar` напрямую — но без `catch`. Исключение из
  /// разбора уходило необработанным, и человек, бросивший файл, не получал
  /// ничего: ни игры, ни сообщения, ни строки в журнале.
  Future<void> _onFilesDropped(
    FilesDropped event,
    Emitter<LibraryState> emit,
  ) async {
    if (event.paths.isEmpty) return;

    final List<DropCandidate> candidates;
    try {
      candidates = await _inspectDrop(event.paths);
    } on Object catch (error) {
      AppLog.instance.write('разбор брошенного в окно', error);
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
      return;
    }

    final added = <Game>[
      for (final candidate in candidates)
        if (candidate.kind != DropKind.unsupported) _gameFromDrop(candidate),
    ];
    if (added.isEmpty) {
      emit(state.copyWith(notice: notice(_l.dropNothing)));
      return;
    }

    emit(
      state.copyWith(
        games: [...state.games, ...added],
        notice: notice(_l.dropAdded(added.length)),
      ),
    );
    _schedulePersist();
    for (final game in added) {
      _queueMetadata(game);
    }
    _drops.add(DroppedGames(games: added, select: event.select));
  }

  /// Заводит всё, что человек отметил в окне поиска.
  ///
  /// Игры уже разобраны сканером: здесь остаётся дать им идентификаторы и
  /// положить в состояние — одной записью, а не десятком.
  void _onScannedGamesAdded(
    ScannedGamesAdded event,
    Emitter<LibraryState> emit,
  ) {
    if (event.games.isEmpty) return;
    final added = [for (final game in event.games) _gameFromScan(game)];
    emit(state.copyWith(games: [...state.games, ...added]));
    _schedulePersist();
    for (final game in added) {
      _queueMetadata(game);
    }
  }

  Game _gameFromScan(ScannedGame scanned) => Game(
    id: const Uuid().v4(),
    title: scanned.title,
    addedAt: DateTime.now(),
    source: GameSource(
      kind: GameSourceKind.localFolder,
      value: scanned.installDir,
    ),
    installDir: scanned.installDir,
    executablePath: scanned.executablePath,
    status: GameStatus.installed,
    steamAppId: scanned.steamAppId,
    saveProfile: SaveProfile(
      autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
      autoSnapshotOnLaunch: settings.state.autoSnapshotOnLaunch,
    ),
  );

  /// Игра из брошенного: папка — уже установленная, `.torrent` — ещё нет.
  Game _gameFromDrop(DropCandidate candidate) {
    final installed = candidate.kind == DropKind.folder;
    return Game(
      id: const Uuid().v4(),
      title: candidate.title,
      addedAt: DateTime.now(),
      source: candidate.source,
      installDir: installed ? candidate.path : null,
      executablePath: candidate.executablePath,
      status: installed ? GameStatus.installed : GameStatus.notInstalled,
      saveProfile: SaveProfile(
        autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
        autoSnapshotOnLaunch: settings.state.autoSnapshotOnLaunch,
      ),
    );
  }
}
