part of 'saves_bloc.dart';

/// Подсказки после выхода из игры: что изменилось, пока она работала.
extension _SavesHints on SavesBloc {
  /// Смотрит, что изменилось, пока игра работала.
  ///
  /// База путей знает не всякую игру — торрент-релизов в ней нет вовсе. Зато
  /// игра сама создаёт себе папку под сейвы, и промежуток её работы нам
  /// известен точно.
  Future<void> _onSaveHintsRequested(
    SaveHintsRequested event,
    Emitter<SavesState> emit,
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
        notice: notice(_l.noticeSaveHints(fresh.length, event.game.title)),
      ),
    );
  }

  /// Смотрит, лежат ли на диске папки правил игры.
  ///
  /// Одним заходом на все правила: строка правила спрашивала диск сама,
  /// дважды на каждое правило и на каждый кадр.
  Future<void> _onSavePathsPresenceRequested(
    SavePathsPresenceRequested event,
    Emitter<SavesState> emit,
  ) async {
    final presence = <String, bool>{};
    for (final rule in event.game.saveProfile.rules) {
      final resolved = rule.resolve(gameDir: event.game.installDir);
      if (resolved == null) continue;
      // Папка сохранений бывает на сетевом диске, который отвечает
      // секундами: синхронный вопрос держал бы на это время кадр.
      presence[resolved] = await _pathExists(resolved);
    }
    if (presence.isEmpty) return;
    emit(state.copyWith(pathPresence: {...state.pathPresence, ...presence}));
  }

  /// Ищет папку по названию игры в местах, где сохранения держат обычно.
  ///
  /// Обход идёт секундами, а клавиша всё это время на экране: без ключа
  /// занятости второе нажатие запускало бы второй обход и второй разговор
  /// об одном и том же.
  Future<void> _onSavePathSuggestionsRequested(
    SavePathSuggestionsRequested event,
    Emitter<SavesState> emit,
  ) async {
    final key = SavesBloc.suggestKey(event.game.id);
    if (state.isBusy(key)) return;
    emit(state.copyWith(busy: busyWith(key, value: true)));

    final List<SavePathSuggestion> found;
    try {
      found = await SavePathFinder.suggest(
        event.game.title,
        searchRoots: _saveRoots(),
      );
    } on Object catch (error) {
      AppLog.instance.write('поиск папок «${event.game.title}»', error);
      finishBusy(emit, key, message: _l.noSimilarFolders, isError: true);
      return;
    }

    final fresh = _withoutKnownPaths(event.game, found);
    if (fresh.isEmpty) {
      finishBusy(emit, key, message: _l.noSimilarFolders);
      return;
    }

    emit(
      state.copyWith(
        busy: busyWith(key, value: false),
        saveHints: {...state.saveHints, event.game.id: fresh},
        notice: notice(_l.noticeSavePathsFound(fresh.length)),
      ),
    );
  }

  Future<void> _onSaveHintsAccepted(
    SaveHintsAccepted event,
    Emitter<SavesState> emit,
  ) async {
    final current = library.state.gameById(event.game.id);
    if (current == null || event.suggestions.isEmpty) return;

    final added = current.saveProfile.rulesForNewPaths([
      for (final item in event.suggestions) item.template,
    ]);
    if (added.isEmpty) {
      emit(state.copyWith(saveHints: _withoutHints(current.id)));
      return;
    }

    _addRules(current, added);
    emit(
      state.copyWith(
        saveHints: _withoutHints(current.id),
        notice: notice(
          _l.noticePathsAdded(
            _sourceLabel(_l, event.suggestions.first.origin),
            added.length,
            current.title,
          ),
        ),
      ),
    );
  }

  void _onSaveHintsDismissed(
    SaveHintsDismissed event,
    Emitter<SavesState> emit,
  ) => emit(state.copyWith(saveHints: _withoutHints(event.gameId)));
}

/// Откуда пришли подсказки — словом, для сообщения человеку.
String _sourceLabel(L l, SavePathOrigin origin) => switch (origin) {
  SavePathOrigin.watch => l.sourceWatch,
  SavePathOrigin.title => l.sourceTitle,
};

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
