part of 'library_bloc.dart';

/// Название, обложка, `appid` — и пути сохранений, которые по нему
/// находятся.
///
/// Цепочка здесь одна: имя раздачи → название → `appid` → пути
/// сохранений, и разносить её по файлам незачем.
extension _LibraryMetadata on LibraryBloc {
  void _queueMetadata(Game game, {String? query}) {
    if (_closing ||
        !automaticMetadata ||
        !game.isInstalled ||
        game.installDir == null) {
      return;
    }
    // Через Steam проходят и те игры, чей идентификатор уже известен: по
    // названию их искать не нужно, а обложка и описание нужны так же.
    if (!game.steamLookupAttempted) {
      add(SteamLookupRequested(game, query: query, automatic: true));
    } else if (game.steamAppId != null && !game.savePathsLookupAttempted) {
      add(SavePathsLookupRequested(game, automatic: true));
    }
  }

  /// Ищет игру в Steam и дополняет карточку. Название не трогаем: имя
  /// в библиотеке пользователь мог задать сам.
  Future<void> _onSteamLookup(
    SteamLookupRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.steamKey(event.game.id);
    final game = state.gameById(event.game.id);
    // Наличия идентификатора для отказа мало: он мог прийти из манифеста
    // Steam на диске, и тогда обложки у игры ещё нет. Отказывает только
    // маркер «уже пробовали».
    if (game == null ||
        state.isBusy(key) ||
        (event.automatic && game.steamLookupAttempted)) {
      return;
    }
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      _replaceGame(game.copyWith(steamLookupAttempted: true), emit);
      // Маркер записан до сети: даже аварийный выход не вызывает повтор.
      await persist();
      // Идентификатор уже известен — спрашиваем прямо по нему. Поиск по
      // названию тут не только лишний, но и вреден: он способен ответить
      // другой игрой.
      final match = game.steamAppId != null
          ? await steam.details(game.steamAppId!)
          : await steam.bestMatch(event.query ?? game.title);
      if (_closing) return;
      if (match == null) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: event.automatic
                ? state.notice
                : _notice(_l.noticeSteamNothingFound),
          ),
        );
        return;
      }

      // Обзоры — отдельным запросом: в `appdetails` их нет вовсе. Своя
      // попытка и свой отказ: промолчи Steam об обзорах, игра всё равно
      // получит и обложку, и описание, и пути сохранений — терять их
      // из-за числа рядом с оценкой не за что.
      SteamReviews? reviews;
      try {
        reviews = await steam.reviews(match.appId);
      } on Object {
        reviews = null;
      }
      if (_closing) return;

      final coverBytes = await steam.coverBytes(match);
      if (_closing) return;
      var current = state.gameById(game.id);
      if (current == null || current.addedAt != game.addedAt) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        return;
      }

      var coverPath = current.coverPath;
      final previousCover = coverPath;
      if (coverBytes != null &&
          (coverPath == null || p.isWithin(_coversDir, coverPath))) {
        final file = File(
          p.join(
            _coversDir,
            '${safeFileName(game.id)}-${DateTime.now().microsecondsSinceEpoch}-steam.jpg',
          ),
        );
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(coverBytes, flush: true);
          coverPath = file.path;
        } on FileSystemException {
          // Ошибка кэша обложки не отменяет ID, описание и поиск сейвов.
        }
        current = state.gameById(game.id);
        if (current == null || current.addedAt != game.addedAt) {
          if (await file.exists()) await file.delete();
          emit(state.copyWith(busy: _withBusy(key, false)));
          return;
        }
      }

      final index = state.games.indexWhere((g) => g.id == game.id);
      final games = [...state.games];
      final rating = GameRating(
        score: reviews?.score,
        summary: reviews?.summary,
        positive: reviews?.positive ?? 0,
        negative: reviews?.negative ?? 0,
        metacritic: match.metacritic,
      );
      games[index] = current.copyWith(
        steamAppId: match.appId,
        coverUrl: match.headerImage,
        description: match.description,
        coverPath: coverPath,
        // Пустую оценку не записываем: сорвавшийся запрос стёр бы то, что
        // уже показано, и страница обеднела бы от неудачного обновления.
        rating: rating.hasAnything ? rating : current.rating,
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: event.automatic
              ? state.notice
              : _notice(_l.noticeSteamFound(match.name)),
        ),
      );
      await persist();
      if (previousCover != null &&
          previousCover != coverPath &&
          p.isWithin(_coversDir, previousCover)) {
        try {
          final old = File(previousCover);
          if (await old.exists()) await old.delete();
        } on FileSystemException {
          // Неудачная уборка старой обложки не отменяет новые метаданные.
        }
      }
      final updated = state.gameById(game.id);
      if (!_closing &&
          updated != null &&
          (!event.automatic || !updated.savePathsLookupAttempted)) {
        add(SavePathsLookupRequested(updated, automatic: event.automatic));
      }
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Заводит игру в Steam сторонним ярлыком.
  ///
  /// Событием, а не вызовом из виджета: запись идёт в чужой файл и
  /// отказывает по-разному — Steam запущен, список не разобрать, — а
  /// объяснять такое человеку умеет общий слушатель оболочки.
  Future<void> _onSteamShortcut(
    SteamShortcutRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.steamShortcutKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      await _steamShortcuts.addGame(
        event.game,
        artwork: await _steamArtwork(event.game),
      );
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(_l.noticeSteamAdded(event.game.title)),
        ),
      );
    } on SteamShortcutException catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.message, isError: true),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Витрина для Steam — четыре картинки с его же CDN.
  ///
  /// Лучшее, что можно положить, рисовал сам Steam и для этой самой игры.
  /// Наша сохранённая обложка закрывает одну створку из четырёх: сетку
  /// библиотеки. Страница игры и полка «недавних» остались бы пустыми, а
  /// именно они и отличают заведённую игру от сироты в списке.
  ///
  /// Дело необязательное: нет сети, нет `appid` — ярлык заводится
  /// по-прежнему, просто с одной обложкой вместо четырёх.
  ///
  /// Четыре запроса разом здесь не то же, что залп по каталогу из
  /// `SteamLookupRequested`: там сорок игр ломились в опросную точку
  /// магазина, здесь одна игра берёт четыре картинки с раздающей сети — и
  /// берёт по прямой просьбе человека, которому кнопку пришлось нажать.
  /// Последовательно эти четыре ожидания сложились бы в минуту на одну
  /// зависшую.
  Future<SteamArtwork?> _steamArtwork(Game game) async {
    final appId = game.steamAppId;
    if (appId == null) return null;
    try {
      final images = await Future.wait([
        steam.imageBytes(SteamCatalog.portraitUrl(appId)),
        steam.imageBytes(SteamCatalog.capsuleUrl(appId)),
        steam.imageBytes(SteamCatalog.heroUrl(appId)),
        steam.imageBytes(SteamCatalog.logoUrl(appId)),
      ]);
      return SteamArtwork(
        portrait: images[0],
        capsule: images[1],
        hero: images[2],
        logo: images[3],
      );
    } on Object catch (error) {
      // Без витрины ярлык всё равно заводится — молчать об этом можно,
      // потеряв лишь красоту, но след оставляем.
      AppLog.instance.write('витрина Steam для «${game.title}»', error);
      return null;
    }
  }

  /// Просит поискать метаданные заново для всех игр, которым их не хватает.
  ///
  /// Маркер «уже пробовали» снимается только здесь и только по нажатию
  /// человека. Автоматически он не снимается никогда: иначе приложение при
  /// каждом запуске ходило бы в Steam за играми, которых там попросту нет,
  /// — а таких в торрент-библиотеке половина.
  ///
  /// Нехватка — это и пустая оценка, а не только пустой `appid`. Библиотеки
  /// собирались до того, как появились обзоры, и у сложившейся библиотеки
  /// цепочка пройдена до конца: без этой ветки кнопка отвечала бы
  /// «метаданные есть у всех», а оценку пришлось бы добывать по одной игре
  /// на её странице. Игру, у которой в Steam и правда нет ни обзоров, ни
  /// Metacritic, кнопка будет переспрашивать каждый раз — отличить «сходили
  /// и не нашли» от «не ходили» по пустому полю нечем, а нажатие тут всегда
  /// человеческое.
  Future<void> _onMetadataRetry(
    MetadataRetryRequested event,
    Emitter<LibraryState> emit,
  ) async {
    // Сводить в Steam или только искать пути: у похода в Steam своё событие,
    // и промахнись отбор — игра снимет не тот маркер и уйдёт не туда.
    bool needsSteam(Game game) =>
        game.steamAppId == null || game.rating == null;

    final pending = [
      for (final game in state.games)
        if (game.isInstalled &&
            game.installDir != null &&
            (needsSteam(game) || !game.savePathsLookupAttempted))
          game,
    ];
    if (pending.isEmpty) {
      emit(state.copyWith(notice: _notice(_l.noticeMetadataNothingToDo)));
      return;
    }

    for (final game in pending) {
      _replaceGame(
        needsSteam(game)
            ? game.copyWith(steamLookupAttempted: false)
            : game.copyWith(savePathsLookupAttempted: false),
        emit,
      );
    }
    await persist();

    // Дальше — обычная очередь: события идут по одному, и залпа не будет.
    for (final game in pending) {
      final current = state.gameById(game.id);
      if (current == null) continue;
      add(
        needsSteam(current)
            ? SteamLookupRequested(current, automatic: true)
            : SavePathsLookupRequested(current, automatic: true),
      );
    }
    emit(
      state.copyWith(notice: _notice(_l.noticeMetadataRetry(pending.length))),
    );
  }

  /// Подбирает папки сохранений по базе. Уже заданные правила не трогаем:
  /// пользователь мог поправить путь под себя.
  void _onSavePathsProgress(
    SavePathsProgressChanged event,
    Emitter<LibraryState> emit,
  ) => emit(state.copyWith(savePathsProgress: event.progress));

  /// Ищет пути в базе и доводит их до состояния, пригодного для правила.
  ///
  /// База пишет пути с масками («любой профиль») и плейсхолдером `<base>` —
  /// папкой самой игры. Первое раскрывается по тому, что лежит на диске,
  /// второе мы знаем сами: игру ставил этот же лончер.
  Future<_FoundPaths?> _lookupPaths(SavePathsLookupRequested event) async {
    await savePaths.ensureLoaded(refresh: event.refresh);
    final entry = savePaths.find(
      title: event.game.title,
      steamAppId: event.game.steamAppId,
    );
    if (entry == null) return null;

    final gameDir = event.game.installDir;
    final templates = <String>[];
    for (final template in entry.templates) {
      for (final resolved in await SavePathGlobs.expand(
        template,
        gameDir: gameDir,
      )) {
        if (!templates.contains(resolved)) templates.add(resolved);
      }
    }

    return _FoundPaths(
      title: entry.title,
      templates: SavePathRule.withoutNested(templates),
      sourceTemplates: entry.templates,
      registryKeys: entry.registryKeys,
    );
  }

  Future<void> _onSavePathsLookup(
    SavePathsLookupRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = LibraryBloc.savePathsKey(event.game.id);
    final game = state.gameById(event.game.id);
    if (game == null ||
        state.isBusy(key) ||
        (event.automatic &&
            (game.steamAppId == null || game.savePathsLookupAttempted))) {
      return;
    }
    emit(state.copyWith(busy: _withBusy(key, true)));
    // Указатель хода гасим в любом случае: оставшись висеть, он врал бы
    // о продолжающейся работе.
    void done() {
      if (!_closing) add(const SavePathsProgressChanged(null));
    }

    try {
      _replaceGame(game.copyWith(savePathsLookupAttempted: true), emit);
      await persist();
      final entry = await _lookupPaths(
        SavePathsLookupRequested(game, refresh: event.refresh),
      );
      if (_closing) return;

      if (entry == null) {
        emit(
          state.copyWith(
            busy: _withBusy(key, false),
            notice: event.automatic
                ? state.notice
                : _notice(_l.noticePathsNothingFound),
          ),
        );
        done();
        return;
      }

      final current = state.gameById(event.game.id);
      if (current == null || current.addedAt != game.addedAt) {
        emit(state.copyWith(busy: _withBusy(key, false)));
        done();
        return;
      }

      final existing = current.saveProfile.rules.map((r) => r.template).toSet();
      final added = <SavePathRule>[
        for (final template in entry.templates)
          if (!existing.contains(template))
            SavePathRule(
              id: const Uuid().v4(),
              label: entry.labelFor(template),
              template: template,
            ),
      ];

      final games = [...state.games];
      games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
        ludusaviTemplates: entry.sourceTemplates,
        ludusaviResolvedPaths: {
          ...current.ludusaviResolvedPaths,
          ...entry.templates,
        }.toList(),
        saveProfile: current.saveProfile.copyWith(
          rules: [...current.saveProfile.rules, ...added],
        ),
      );
      emit(
        state.copyWith(
          games: games,
          busy: _withBusy(key, false),
          notice: event.automatic
              ? state.notice
              : _notice(
                  entry.isEmpty
                      ? _l.noticePathsNothingFound
                      : added.isEmpty
                      ? _l.noticePathsAlreadySet
                      : entry.describe(_l, added.length),
                ),
        ),
      );
      await persist();
      done();
    } on Object catch (error) {
      done();
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  /// Снимает сохранения всех настроенных игр и складывает пакеты в папку —
  /// то, с чего начинается переезд на другое устройство.
}

/// Найденные пути и то, откуда они взялись.
class _FoundPaths {
  _FoundPaths({
    required this.title,
    required this.templates,
    this.sourceTemplates = const [],
    this.registryKeys = const [],
  });

  final String title;
  final List<String> templates;
  final List<String> sourceTemplates;
  final List<String> registryKeys;

  bool get isEmpty => templates.isEmpty;

  late final List<String> _labels = SavePathRule.labelsFor(templates);

  String labelFor(String template) => _labels[templates.indexOf(template)];

  String describe(L l, int added) {
    final message = l.noticePathsAdded(l.sourceDatabase, added, title);
    if (registryKeys.isEmpty) return message;
    // Реестр мы не переносим, но умолчать о нём нельзя: иначе пользователь
    // решит, что забрал сейв целиком.
    return l.noticeRegistryLeft(message, registryKeys.length);
  }
}
