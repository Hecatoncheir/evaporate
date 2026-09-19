part of 'saves_bloc.dart';

/// Снимки: снятие, разворачивание, ротация и уборка за ними.
extension _SavesSnapshots on SavesBloc {
  /// Маски раскрываются локально: папка профиля могла появиться только
  /// после первого запуска. Сохранённый манифест повторно не запрашиваем.
  Future<Game?> _resolveStoredPaths(Game game, Emitter<SavesState> emit) async {
    final expanded = <String>{};
    for (final template in game.ludusaviTemplates) {
      expanded.addAll(
        await SavePathGlobs.expand(template, gameDir: game.installDir),
      );
    }
    final current = library.state.gameById(game.id);
    if (current == null || current.addedAt != game.addedAt) return null;
    final existing = current.saveProfile.rules
        .map((rule) => rule.template)
        .toSet();
    final added = SavePathRule.withoutNested(expanded.toList())
        .where(
          (path) =>
              !existing.contains(path) &&
              !current.ludusaviResolvedPaths.contains(path),
        )
        .toList();
    if (added.isEmpty) return current;
    return _addRules(
      current,
      current.saveProfile.rulesForNewPaths(added),
      resolvedPaths: expanded.toList(),
    );
  }

  Future<void> _onSnapshotRequested(
    SnapshotRequested event,
    Emitter<SavesState> emit,
  ) async {
    final initial = library.state.gameById(event.game.id);
    if (initial == null) return;
    var game = initial;
    // Автоснимок после выхода из игры человек не просил — и об удаче ему
    // сообщать незачем. О неудаче сообщаем уведомлением: окна он уже
    // не видит.
    final silent = event.origin == SnapshotOrigin.autoOnExit;
    final key = SavesBloc.snapshotKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));

    try {
      final resolved = await _resolveStoredPaths(game, emit);
      if (resolved == null) {
        _finishBusy(emit, key);
        return;
      }
      game = resolved;
      final snapshot = await _saves.createSnapshot(
        game,
        origin: event.origin,
        note: event.note,
      );

      // Снимок заносим в библиотеку сразу, до выгрузки наружу: пока его нет
      // в состоянии, на его содержимое не ссылается никто, а уборка от
      // соседнего события бесхозное содержимое уносит. Выгрузка же идёт
      // секундами, а то и не задаётся вовсе — держать ради неё снимок
      // незаписанным значит рисковать им ради необязательного удобства.
      emit(state.copyWith(snapshots: _withSnapshot(snapshot)));
      if (_syncFolderWanted) await _exportToSync(snapshot);

      _finishBusy(
        emit,
        key,
        message: silent
            ? null
            : _l.noticeSnapshotReady(
                snapshot.fileCount,
                formatBytes(snapshot.sizeBytes),
              ),
      );
      await _prune(game.id, emit);
      await persist();
    } on SaveException catch (error) {
      if (silent) _notifySnapshotFailed(game, error.message);
      _finishBusy(
        emit,
        key,
        message: silent ? null : error.message,
        isError: true,
      );
    } on Object catch (error) {
      _finishBusy(emit, key, message: error.toString(), isError: true);
    }
  }

  /// Просили ли класть копию снимка в папку синхронизации.
  ///
  /// Проверка снаружи, а не внутри: ждать шаг, которого нет, значит
  /// отложить сообщение об удаче на лишнюю микрозадачу, а на него смотрят
  /// сразу после появления снимка.
  bool get _syncFolderWanted =>
      settings.state.autoExportToSync && settings.state.syncFolder != null;

  /// Кладёт копию снимка в папку синхронизации. Отказ снимка не отменяет:
  /// локально он уже сохранён.
  Future<void> _exportToSync(SaveSnapshot snapshot) async {
    try {
      await _exportToSyncFolder(snapshot);
    } on Object catch (error) {
      // Папка синхронизации могла отвалиться — снимок сохранён локально.
      AppLog.instance.write('выгрузка в папку синхронизации', error);
    }
  }

  /// Молчаливый автоснимок провалился, и уведомление — единственный способ
  /// сообщить: окна приложения человек в этот момент уже не видит.
  void _notifySnapshotFailed(Game game, String message) {
    _notifySystem(
      AppNotification(
        title: _l.noticeSnapshotFailed,
        body: _l.noticeSaveFailedBody(game.title, message),
        kind: NotificationKind.saveFailed,
      ),
    );
  }

  Map<String, List<SaveSnapshot>> _withSnapshot(SaveSnapshot snapshot) {
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[snapshot.gameId] = [snapshot, ...?snapshots[snapshot.gameId]];
    return snapshots;
  }

  /// Оставляет игре столько снимков, сколько разрешено её профилем.
  ///
  /// По идентификатору, а не по объекту игры: зовётся отовсюду, где снимок
  /// попадает в состояние, а свежую игру там под рукой держат не все.
  /// Путей этих шесть — ручной снимок, автоснимок, резервная копия перед
  /// восстановлением, импорт пакета, массовый перенос и применение из папки
  /// синхронизации, — и раньше ротация случалась только на первых двух.
  /// Диск от остальных рос молча, причём быстрее всего у того, кто и правда
  /// возит сейвы между машинами.
  Future<void> _prune(String gameId, Emitter<SavesState> emit) async {
    final keep = library.state.gameById(gameId)?.saveProfile.keepSnapshots;
    if (keep == null || keep <= 0) return;
    final list = state.snapshots[gameId];
    if (list == null || list.length <= keep) return;

    final excess = list.sublist(keep);
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[gameId] = list.sublist(0, keep);
    emit(state.copyWith(snapshots: snapshots));

    for (final snapshot in excess) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object catch (error) {
        // Пропускаем: ротация не критична, но след оставляем.
        AppLog.instance.write(
          'ротация: не удалить ${snapshot.archivePath}',
          error,
        );
      }
    }
    await _collectGarbage();
  }

  /// Убирает содержимое снимков, на которое больше никто не ссылается.
  ///
  /// Хранилище общее для всех игр, а список живых ссылок целиком виден
  /// только отсюда: снимок можно выкинуть у одной игры, а его файлы —

  Future<void> _onRestoreRequested(
    SnapshotRestoreRequested event,
    Emitter<SavesState> emit,
  ) async {
    final key = SavesBloc.snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: event.snapshot,
        backupCurrent: event.backupCurrent,
        wipeTarget: event.wipeTarget,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice(
                  _l.noticeRestoredFiles(
                    report.filesWritten,
                    formatBytes(report.bytesWritten),
                  ),
                )
              : _notice(
                  _l.noticeUnresolvedPaths(report.unresolved.join(', ')),
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

  Future<void> _onImportRequested(
    SnapshotImportRequested event,
    Emitter<SavesState> emit,
  ) async {
    final key = SavesBloc.snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(
        state.copyWith(
          snapshots: _withSnapshot(snapshot),
          busy: _withBusy(key, false),
          notice: _notice(_l.noticeSnapshotImported),
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

  Future<void> _onExportRequested(
    SnapshotExportRequested event,
    Emitter<SavesState> emit,
  ) async {
    try {
      await _saves.exportSnapshot(event.snapshot, event.destination);
      emit(
        state.copyWith(notice: _notice(_l.noticeSavedTo(event.destination))),
      );
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onSnapshotDeleted(
    SnapshotDeleted event,
    Emitter<SavesState> emit,
  ) async {
    final list = state.snapshots[event.snapshot.gameId];
    if (list != null) {
      final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
      snapshots[event.snapshot.gameId] = list
          .where((s) => s.id != event.snapshot.id)
          .toList();
      emit(state.copyWith(snapshots: snapshots));
    }
    try {
      await _saves.deleteSnapshot(event.snapshot);
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
    await _collectGarbage();
    await persist();
  }

  Future<File> _exportToSyncFolder(SaveSnapshot snapshot) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      throw SaveException(_l.noticeSyncFolderNotSet);
    }
    final name =
        '${safeFileName('${snapshot.gameTitle} - ${snapshot.deviceName}')}'
        '${SaveSnapshot.fileExtension}';
    return _saves.exportSnapshot(snapshot, p.join(folder, name));
  }
}
