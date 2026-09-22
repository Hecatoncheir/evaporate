part of 'saves_bloc.dart';

/// Снимки: снятие, разворачивание, ротация и уборка за ними.
extension _SavesSnapshots on SavesBloc {
  /// Маски раскрываются локально: папка профиля могла появиться только
  /// после первого запуска. Сохранённый манифест повторно не запрашиваем.
  Future<Game?> _resolveStoredPaths(Game game, Emitter<SavesState> emit) async {
    final expanded = <String>{};
    for (final template in game.saveDiscovery.ludusaviTemplates) {
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
              !current.saveDiscovery.ludusaviResolvedPaths.contains(path),
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
    emit(state.copyWith(busy: busyWith(key, value: true)));

    try {
      final resolved = await _resolveStoredPaths(game, emit);
      if (resolved == null) {
        finishBusy(emit, key);
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
      // Список — на диск до выгрузки и до сообщения: «вышел из игры и
      // закрыл лончер» — самый обычный порядок, а выгрузка идёт секундами,
      // и список, записанный после неё, при закрытии терялся.
      await persist();
      if (settings.state.saves.exportsToSync) await _exportToSync(snapshot);

      finishBusy(
        emit,
        key,
        message: silent
            ? null
            : _l.noticeSnapshotReady(
                snapshot.fileCount,
                bytesLabel(_l, snapshot.sizeBytes),
              ),
      );
      await _prune(game.id, emit);
      await persist();
    } on SaveException catch (error) {
      _snapshotFailed(emit, game, key, error.message, silent: silent);
    } on Object catch (error) {
      // Сырое исключение ввода-вывода — файл ещё держит игра — такой же
      // провал, и молчаливому автоснимку сказать о нём больше нечем.
      _snapshotFailed(emit, game, key, '$error', silent: silent);
    }
  }

  /// Снимок не вышел: ручному — сообщением в окне, автоснимку после выхода
  /// — системным уведомлением: окна человек в этот миг уже не видит.
  void _snapshotFailed(
    Emitter<SavesState> emit,
    Game game,
    String key,
    String message, {
    required bool silent,
  }) {
    if (silent) _notifySnapshotFailed(game, message);
    finishBusy(emit, key, message: silent ? null : message, isError: true);
  }

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

  /// Резервная копия перед восстановлением — в состояние и на диск, пока
  /// замена ещё не началась.
  ///
  /// Прежде копия попадала в библиотеку из отчёта об успехе: сорвись замена,
  /// её не было нигде, и следующая уборка уносила её содержимое — ровно
  /// тогда, когда она нужна. Список пишется сразу: упади приложение
  /// посреди замены, копия в одной памяти пропала бы так же.
  Future<void> _keepBackup(
    SaveSnapshot backup,
    Emitter<SavesState> emit,
  ) async {
    emit(state.copyWith(snapshots: _withSnapshot(backup)));
    await persist();
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
    // Список — раньше удаления: оборвись работа между ними, в списке
    // остался бы снимок без содержимого. Наоборот — лишь лишние файлы,
    // которые унесёт следующая уборка.
    await persist();

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

  Future<void> _onRestoreRequested(
    SnapshotRestoreRequested event,
    Emitter<SavesState> emit,
  ) async {
    final key = SavesBloc.snapshotKey(event.game.id);
    emit(state.copyWith(busy: busyWith(key, value: true)));
    try {
      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: event.snapshot,
        backupCurrent: event.backupCurrent,
        wipeTarget: event.wipeTarget,
        onBackup: (backup) => _keepBackup(backup, emit),
      );
      emit(
        state.copyWith(
          busy: busyWith(key, value: false),
          notice: report.isComplete
              ? notice(
                  _l.noticeRestoredFiles(
                    report.filesWritten,
                    bytesLabel(_l, report.bytesWritten),
                  ),
                )
              : notice(
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
          busy: busyWith(key, value: false),
          notice: notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Разбирает выбранный пакет и откладывает его до ответа человека.
  ///
  /// Пакет приходит извне: он может оказаться не тем, битым или вовсе не
  /// пакетом. Раньше это читал виджет, и его `showError` шёл мимо `Notice`
  /// и журнала — то есть мимо всего, по чему потом разбираются.
  Future<void> _onImportInspectRequested(
    SnapshotImportInspectRequested event,
    Emitter<SavesState> emit,
  ) async {
    try {
      final info = await _saves.inspectPackage(event.path);
      emit(
        state.copyWith(
          pendingImport: PendingImport(game: event.game, info: info),
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
  }

  void _onImportDismissed(
    SnapshotImportDismissed event,
    Emitter<SavesState> emit,
  ) => emit(state.copyWith(pendingImport: null));

  Future<void> _onImportRequested(
    SnapshotImportRequested event,
    Emitter<SavesState> emit,
  ) => busyWhile(emit, SavesBloc.snapshotKey(event.game.id), () async {
    emit(state.copyWith(pendingImport: null));
    final snapshot = await _saves.importPackage(event.path, game: event.game);
    emit(state.copyWith(snapshots: _withSnapshot(snapshot)));
    await _prune(event.game.id, emit);
    await persist();
    return _l.noticeSnapshotImported;
  });

  Future<void> _onExportRequested(
    SnapshotExportRequested event,
    Emitter<SavesState> emit,
  ) async {
    try {
      await _saves.exportSnapshot(event.snapshot, event.destination);
      emit(state.copyWith(notice: notice(_l.noticeSavedTo(event.destination))));
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
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
    // Список — раньше удаления и уборки, по той же причине, что в
    // `_prune`.
    await persist();
    try {
      await _saves.deleteSnapshot(event.snapshot);
    } on Object catch (error) {
      emit(state.copyWith(notice: notice(error.toString(), isError: true)));
    }
    await _collectGarbage();
  }

  Future<File> _exportToSyncFolder(SaveSnapshot snapshot) async {
    final folder = settings.state.saves.syncFolder;
    if (folder == null) {
      throw SaveException(_l.noticeSyncFolderNotSet);
    }
    final name =
        '${safeFileName('${snapshot.gameTitle} - ${snapshot.deviceName}')}'
        '${SaveSnapshot.fileExtension}';
    return _saves.exportSnapshot(snapshot, p.join(folder, name));
  }
}
