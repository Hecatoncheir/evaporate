part of 'saves_bloc.dart';

/// Перенос сохранений всей библиотеки разом и папка синхронизации.
extension _SavesBulk on SavesBloc {
  Future<void> _onBulkExport(
    BulkExportRequested event,
    Emitter<SavesState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(SavesBloc.bulkKey, true)));
    // Сбой по отдельной игре — строка отчёта, а не исключение; сюда
    // доходит только провал всей операции: не записался список снимков,
    // не прошла ротация. Занятость гасится и тогда — иначе клавиши
    // переноса погасли бы до перезапуска.
    try {
      for (final game in library.state.games) {
        await _resolveStoredPaths(game, emit);
      }

      final result = await _bulk.exportAll(
        games: library.state.games,
        destinationDir: event.destinationDir,
        // Снимок ложится в состояние сразу, а не всей пачкой в конце:
        // выгрузка большой библиотеки идёт минуты.
        onSnapshot: (snapshot) =>
            emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
      );

      await _pruneAll(emit);
      await persist();
      _finishBulk(emit, result);
    } on Object catch (error) {
      _failBulk(emit, error);
    }
  }

  void _finishBulk(Emitter<SavesState> emit, BulkResult result) => emit(
    state.copyWith(
      busy: _withBusy(SavesBloc.bulkKey, false),
      bulkReport: result.report,
      notice: _notice(result.message, isError: result.isError),
    ),
  );

  void _failBulk(Emitter<SavesState> emit, Object error) => emit(
    state.copyWith(
      busy: _withBusy(SavesBloc.bulkKey, false),
      notice: _notice(error.toString(), isError: true),
    ),
  );

  /// Ротация по всей библиотеке разом.
  ///
  /// Массовый перенос кладёт снимки колбэком, из чужого кода, — там их не
  /// почистить: колбэк синхронный, а удаление файлов нет. Поэтому чистим
  /// после, одним проходом.
  Future<void> _pruneAll(Emitter<SavesState> emit) async {
    for (final id in library.state.games.map((game) => game.id).toList()) {
      await _prune(id, emit);
    }
  }

  Future<void> _onBulkImport(
    BulkImportRequested event,
    Emitter<SavesState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(SavesBloc.bulkKey, true)));
    // Папку не прочитать — разбирать нечего: это провал всей операции, а
    // не исход отдельной игры, и отчёта по играм тут не будет.
    try {
      final result = await _bulk.importAll(
        games: library.state.games,
        sourceDir: event.sourceDir,
        overwriteNewer: event.overwriteNewer,
        onSnapshot: (snapshot) =>
            emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
      );
      await _pruneAll(emit);
      await persist();
      _finishBulk(emit, result);
    } on Object catch (error) {
      _failBulk(emit, error);
    }
  }

  Future<void> _onSyncScanRequested(
    SyncFolderScanRequested event,
    Emitter<SavesState> emit,
  ) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      emit(state.copyWith(syncPackages: const [], syncScanned: true));
      return;
    }
    emit(state.copyWith(scanningSync: true));
    try {
      final packages = await _saves.scanSyncFolder(folder);
      emit(
        state.copyWith(
          syncPackages: packages,
          scanningSync: false,
          syncScanned: true,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          scanningSync: false,
          syncScanned: true,
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onSyncPackageApplied(
    SyncPackageApplied event,
    Emitter<SavesState> emit,
  ) async {
    final key = SavesBloc.snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(state.copyWith(snapshots: _withSnapshot(snapshot)));

      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: snapshot,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice(_l.noticeRestoreDone(report.filesWritten))
              : _notice(
                  _l.noticeUnresolvedShort(report.unresolved.join(', ')),
                  isError: true,
                ),
        ),
      );
      await _prune(event.game.id, emit);
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }
}
