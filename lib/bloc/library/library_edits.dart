part of 'library_bloc.dart';

/// Правки игры: каждое событие называет, что меняется, и применяется к
/// игре такой, какая она в состоянии сейчас, — см. `library_event.dart`.
extension _LibraryEdits on LibraryBloc {
  /// Меняет игру [gameId] функцией от её **текущего** вида и откладывает
  /// запись. Игры уже нет — правка молча пропадает: её удалили, пока
  /// событие шло.
  Game? _edit(
    String gameId,
    Emitter<LibraryState> emit,
    Game Function(Game current) change,
  ) {
    final index = state.games.indexWhere((g) => g.id == gameId);
    if (index == -1) return null;
    final updated = change(state.games[index]);
    final games = [...state.games];
    games[index] = updated;
    emit(state.copyWith(games: games));
    _schedulePersist();
    return updated;
  }

  void _onStatusChanged(GameStatusChanged event, Emitter<LibraryState> emit) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        status: event.status,
        lastError: event.status == GameStatus.error
            ? event.lastError
            : game.lastError,
      ),
    );
  }

  void _onDownloadStarted(
    GameDownloadStarted event,
    Emitter<LibraryState> emit,
  ) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        source: event.source,
        status: GameStatus.downloading,
        downloadTaskId: event.taskId,
        lastError: null,
      ),
    );
  }

  void _onDownloadLinked(GameDownloadLinked event, Emitter<LibraryState> emit) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        downloadTaskId: event.taskId ?? game.downloadTaskId,
        infoHash: event.infoHash ?? game.infoHash,
      ),
    );
  }

  void _onDownloadDropped(
    GameDownloadDropped event,
    Emitter<LibraryState> emit,
  ) {
    _edit(
      event.gameId,
      emit,
      (game) =>
          game.copyWith(status: GameStatus.notInstalled, downloadTaskId: null),
    );
  }

  void _onDownloadFinished(
    GameDownloadFinished event,
    Emitter<LibraryState> emit,
  ) {
    final game = _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        status: GameStatus.installed,
        installDir: event.installDir,
        downloadTaskId: null,
        sizeBytes: event.sizeBytes,
        lastError: null,
        executablePath: game.executablePath ?? event.executablePath,
      ),
    );
    if (game != null) _queueMetadata(game, query: event.metadataQuery);
  }

  void _onDownloadRejected(
    GameDownloadRejected event,
    Emitter<LibraryState> emit,
  ) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        status: GameStatus.error,
        installDir: event.installDir,
        downloadTaskId: null,
        lastError: event.reason,
      ),
    );
  }

  void _onExecutableSet(GameExecutableSet event, Emitter<LibraryState> emit) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(executablePath: event.path),
    );
  }

  /// Поиск исполняемого — здесь, а не в виджете: обход папки идёт секунды,
  /// и за это время выбранное человеком могло появиться. Догадка его не
  /// заменяет, поэтому применяется к текущей игре, а не к той, что была
  /// до обхода.
  Future<void> _onInstallDirSet(
    GameInstallDirSet event,
    Emitter<LibraryState> emit,
  ) async {
    final candidates = await ExecutableFinder.scan(event.dir);
    final guess = candidates.isEmpty ? null : candidates.first.path;
    final game = _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        installDir: event.dir,
        status: GameStatus.installed,
        executablePath: game.executablePath ?? guess,
      ),
    );
    if (game != null) _queueMetadata(game);
  }

  void _onSaveRulesAdded(SaveRulesAdded event, Emitter<LibraryState> emit) {
    _edit(event.gameId, emit, (game) {
      final known = {for (final rule in game.saveProfile.rules) rule.template};
      return game.copyWith(
        ludusaviResolvedPaths: {
          ...game.ludusaviResolvedPaths,
          ...event.resolvedPaths,
        }.toList(),
        saveProfile: game.saveProfile.copyWith(
          rules: [
            ...game.saveProfile.rules,
            for (final rule in event.rules)
              if (known.add(rule.template)) rule,
          ],
        ),
      );
    });
  }

  void _onSaveRuleRemoved(SaveRuleRemoved event, Emitter<LibraryState> emit) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        saveProfile: game.saveProfile.copyWith(
          rules: [
            for (final rule in game.saveProfile.rules)
              if (rule.id != event.ruleId) rule,
          ],
        ),
      ),
    );
  }

  void _onAutoSnapshotChanged(
    AutoSnapshotChanged event,
    Emitter<LibraryState> emit,
  ) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        saveProfile: game.saveProfile.copyWith(
          autoSnapshotOnExit: event.onExit,
          autoSnapshotOnLaunch: event.onLaunch,
        ),
      ),
    );
  }
}
