part of 'library_bloc.dart';

/// Снимки сохранений: снятие, разворачивание, ротация и перенос всей
/// библиотеки разом.
///
/// Отдельный файл, а не отдельный класс: обработчики правят состояние
/// блока и без него не живут. `part` — тот же способ, каким у блока уже
/// разложены события и состояние.
extension _LibrarySaves on LibraryBloc {
  /// Маски раскрываются локально: папка профиля могла появиться только
  /// после первого запуска. Сохранённый манифест повторно не запрашиваем.
  Future<Game?> _resolveStoredPaths(
    Game game,
    Emitter<LibraryState> emit,
  ) async {
    final expanded = <String>{};
    for (final template in game.ludusaviTemplates) {
      expanded.addAll(
        await SavePathGlobs.expand(template, gameDir: game.installDir),
      );
    }
    final current = state.gameById(game.id);
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
    final updated = current.copyWith(
      ludusaviResolvedPaths: {
        ...current.ludusaviResolvedPaths,
        ...expanded,
      }.toList(),
      saveProfile: current.saveProfile.copyWith(
        rules: [...current.saveProfile.rules, ..._rulesFor(existing, added)],
      ),
    );
    _replaceGame(updated, emit);
    await persist();
    return updated;
  }

  Future<void> _onSnapshotRequested(
    SnapshotRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final initial = state.gameById(event.game.id);
    if (initial == null) return;
    var game = initial;
    // Автоснимок после выхода из игры человек не просил — и об удаче ему
    // сообщать незачем. О неудаче сообщаем уведомлением: окна он уже
    // не видит.
    final silent = event.origin == SnapshotOrigin.autoOnExit;
    final key = LibraryBloc.snapshotKey(game.id);
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
  Future<void> _prune(String gameId, Emitter<LibraryState> emit) async {
    final keep = state.gameById(gameId)?.saveProfile.keepSnapshots;
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
  /// оставаться нужными другой, если обе привезли один и тот же пакет.
  Future<void> _collectGarbage() async {
    try {
      final freed = await _saves.collectGarbage(
        state.snapshots.values.expand((list) => list),
      );
      // Только когда и правда убрали: уборка идёт следом за каждым снимком
      // и чаще всего не находит ничего, а журнал, полный нулей, никто
      // читать не станет. Зато «куда делись гигабайты» — вопрос, который
      // задают через неделю, и ответ на него должен где-то лежать.
      if (freed > 0) {
        AppLog.instance.write(
          'уборка хранилища снимков освободила ${formatBytes(freed)}',
        );
      }
    } on Object catch (error) {
      // Уборка — дело подсобное: не вышло, значит место освободится позже.
      AppLog.instance.write('уборка хранилища снимков', error);
    }
  }

  Future<void> _onRestoreRequested(
    SnapshotRestoreRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.snapshotKey(event.game.id);
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
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.snapshotKey(event.game.id);
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
    Emitter<LibraryState> emit,
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
    Emitter<LibraryState> emit,
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

  /// Смотрит, что изменилось, пока игра работала.
  ///
  /// База путей знает не всякую игру — торрент-релизов в ней нет вовсе. Зато
  /// игра сама создаёт себе папку под сейвы, и промежуток её работы нам
  /// известен точно.
  Future<void> _onSaveHintsRequested(
    SaveHintsRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final List<SavePathSuggestion> found;
    try {
      found = await SaveActivityWatch.changedSince(
        event.since,
        gameTitle: event.game.title,
        gameDir: event.game.installDir,
        roots: _saveRoots(),
      );
    } on Object catch (error) {
      // Обход папок — дело подсобное: не вышло, значит подсказок не будет.
      AppLog.instance.write('поиск следов игры «${event.game.title}»', error);
      return;
    }

    final fresh = _withoutKnownPaths(event.game, found);
    if (fresh.isEmpty) return;

    emit(
      state.copyWith(
        saveHints: {...state.saveHints, event.game.id: fresh},
        notice: _notice(_l.noticeSaveHints(fresh.length, event.game.title)),
      ),
    );
  }

  Future<void> _onSaveHintsAccepted(
    SaveHintsAccepted event,
    Emitter<LibraryState> emit,
  ) async {
    final current = state.gameById(event.game.id);
    if (current == null || event.suggestions.isEmpty) return;

    final existing = current.saveProfile.rules.map((r) => r.template).toSet();
    final templates = [
      for (final item in event.suggestions)
        if (!existing.contains(item.template)) item.template,
    ];
    if (templates.isEmpty) {
      emit(state.copyWith(saveHints: _withoutHints(current.id)));
      return;
    }

    final added = _rulesFor(existing, templates);

    final games = [...state.games];
    games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
      saveProfile: current.saveProfile.copyWith(
        rules: [...current.saveProfile.rules, ...added],
      ),
    );
    emit(
      state.copyWith(
        games: games,
        saveHints: _withoutHints(current.id),
        notice: _notice(
          _l.noticePathsAdded(_l.sourceWatch, added.length, current.title),
        ),
      ),
    );
    _schedulePersist();
  }

  void _onSaveHintsDismissed(
    SaveHintsDismissed event,
    Emitter<LibraryState> emit,
  ) => emit(state.copyWith(saveHints: _withoutHints(event.gameId)));

  Map<String, List<SavePathSuggestion>> _withoutHints(String gameId) => {
    for (final entry in state.saveHints.entries)
      if (entry.key != gameId) entry.key: entry.value,
  };

  Future<void> _onBulkExport(
    BulkExportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(LibraryBloc.bulkKey, true)));

    for (final game in state.games) {
      await _resolveStoredPaths(game, emit);
    }

    final result = await _bulk.exportAll(
      games: state.games,
      destinationDir: event.destinationDir,
      // Снимок ложится в состояние сразу, а не всей пачкой в конце:
      // выгрузка большой библиотеки идёт минуты.
      onSnapshot: (snapshot) =>
          emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
    );

    await _pruneAll(emit);
    await persist();
    emit(
      state.copyWith(
        busy: _withBusy(LibraryBloc.bulkKey, false),
        bulkReport: result.report,
        notice: _notice(result.message, isError: result.isError),
      ),
    );
  }

  /// Ротация по всей библиотеке разом.
  ///
  /// Массовый перенос кладёт снимки колбэком, из чужого кода, — там их не
  /// почистить: колбэк синхронный, а удаление файлов нет. Поэтому чистим
  /// после, одним проходом.
  Future<void> _pruneAll(Emitter<LibraryState> emit) async {
    for (final id in state.games.map((game) => game.id).toList()) {
      await _prune(id, emit);
    }
  }

  Future<void> _onBulkImport(
    BulkImportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(busy: _withBusy(LibraryBloc.bulkKey, true)));

    final BulkResult result;
    try {
      result = await _bulk.importAll(
        games: state.games,
        sourceDir: event.sourceDir,
        overwriteNewer: event.overwriteNewer,
        onSnapshot: (snapshot) =>
            emit(state.copyWith(snapshots: _withSnapshot(snapshot))),
      );
    } on Object catch (error) {
      // Папку не прочитать — разбирать нечего: это провал всей операции,
      // а не исход отдельной игры, и отчёта по играм тут не будет.
      emit(
        state.copyWith(
          busy: _withBusy(LibraryBloc.bulkKey, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
      return;
    }

    await _pruneAll(emit);
    await persist();
    emit(
      state.copyWith(
        busy: _withBusy(LibraryBloc.bulkKey, false),
        bulkReport: result.report,
        notice: _notice(result.message, isError: result.isError),
      ),
    );
  }

  Future<void> _onSyncScanRequested(
    SyncFolderScanRequested event,
    Emitter<LibraryState> emit,
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
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.snapshotKey(event.game.id);
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

/// Правила для путей, добавляемых к уже заданным.
///
/// Метки считает по всему набору сразу, а не по одним новым: по метке
/// правила сопоставляются между устройствами, и совпавшая метка склеила бы
/// разные сейвы. Три обработчика добавляют пути из разных источников —
/// сохранённого манифеста, подсказок после игры и ручного поиска, — и
/// расходиться в этом им нельзя.
List<SavePathRule> _rulesFor(Iterable<String> existing, List<String> added) {
  final before = existing.toList();
  final labels = SavePathRule.labelsFor([...before, ...added]);
  return [
    for (var i = 0; i < added.length; i++)
      SavePathRule(
        id: const Uuid().v4(),
        label: labels[before.length + i],
        template: added[i],
      ),
  ];
}

/// Отсеивает то, что уже покрыто заданными правилами: подсказывать
/// известное — значит приучить не читать подсказки вовсе.
List<SavePathSuggestion> _withoutKnownPaths(
  Game game,
  List<SavePathSuggestion> found,
) {
  final known = <String>[];
  for (final rule in game.saveProfile.rules) {
    final resolved = rule.resolve(gameDir: game.installDir);
    if (resolved != null) known.add(p.normalize(resolved));
  }
  return [
    for (final item in found)
      if (!known.any(
        (path) => p.equals(path, item.path) || p.isWithin(path, item.path),
      ))
        item,
  ];
}
