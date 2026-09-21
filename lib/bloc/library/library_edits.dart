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
        status: GameStatus.downloading,
        lastError: null,
        download: game.download.copyWith(
          source: event.source,
          downloadTaskId: event.taskId,
        ),
      ),
    );
  }

  void _onDownloadLinked(GameDownloadLinked event, Emitter<LibraryState> emit) {
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(
        download: game.download.copyWith(
          downloadTaskId: event.taskId ?? game.download.downloadTaskId,
          infoHash: event.infoHash ?? game.download.infoHash,
        ),
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
      (game) => game.copyWith(
        status: GameStatus.notInstalled,
        download: game.download.copyWith(downloadTaskId: null),
      ),
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
        download: game.download.copyWith(downloadTaskId: null),
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
        download: game.download.copyWith(downloadTaskId: null),
        lastError: event.reason,
      ),
    );
  }

  void _onExecutableSet(GameExecutableSet event, Emitter<LibraryState> emit) {
    emit(state.copyWith(pendingExecutables: null));
    _edit(
      event.gameId,
      emit,
      (game) => game.copyWith(executablePath: event.path),
    );
  }

  /// Ищет в папке игры, что запускать, и откладывает найденное до выбора.
  ///
  /// Обход идёт секундами: держать его в виджете значило бы держать там же
  /// и его неудачу. Выбирает при этом человек — у сборок с лаунчером и
  /// движком имена похожи до неразличимости.
  Future<void> _onExecutableDetectRequested(
    GameExecutableDetectRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final dir = state.gameById(event.gameId)?.installDir;
    if (dir == null) return;

    final candidates = await ExecutableFinder.scan(dir);
    if (candidates.isEmpty) {
      emit(state.copyWith(notice: notice(_l.noExecutablesFound)));
      return;
    }
    emit(
      state.copyWith(
        pendingExecutables: ExecutablePick(
          gameId: event.gameId,
          candidates: candidates,
        ),
      ),
    );
  }

  void _onExecutablePickDismissed(
    GameExecutablePickDismissed event,
    Emitter<LibraryState> emit,
  ) => emit(state.copyWith(pendingExecutables: null));

  /// Показывает папку установки в проводнике.
  ///
  /// Отказ — обычное дело: папку могли унести на другой диск или удалить
  /// мимо приложения. Человеку об этом говорят тем же `Notice`, что и обо
  /// всём остальном, а не тишиной и не `SnackBar` из виджета.
  Future<void> _onFolderOpenRequested(
    GameFolderOpenRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final dir = state.gameById(event.gameId)?.installDir;
    if (dir == null) return;
    try {
      await _fileManager.openFolder(dir);
    } on FileManagerException catch (error) {
      emit(state.copyWith(notice: notice(error.message, isError: true)));
    }
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
        saveDiscovery: game.saveDiscovery.copyWith(
          ludusaviResolvedPaths: {
            ...game.saveDiscovery.ludusaviResolvedPaths,
            ...event.resolvedPaths,
          }.toList(),
        ),
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
