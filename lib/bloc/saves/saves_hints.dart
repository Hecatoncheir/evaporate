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
        notice: _notice(_l.noticeSaveHints(fresh.length, event.game.title)),
      ),
    );
  }

  Future<void> _onSaveHintsAccepted(
    SaveHintsAccepted event,
    Emitter<SavesState> emit,
  ) async {
    final current = library.state.gameById(event.game.id);
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
    _updateGame(
      current.copyWith(
        saveProfile: current.saveProfile.copyWith(
          rules: [...current.saveProfile.rules, ...added],
        ),
      ),
    );
    emit(
      state.copyWith(
        saveHints: _withoutHints(current.id),
        notice: _notice(
          _l.noticePathsAdded(_l.sourceWatch, added.length, current.title),
        ),
      ),
    );
  }

  void _onSaveHintsDismissed(
    SaveHintsDismissed event,
    Emitter<SavesState> emit,
  ) => emit(state.copyWith(saveHints: _withoutHints(event.gameId)));
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
