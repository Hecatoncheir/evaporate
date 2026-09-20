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
  ///
  /// Читается сверху вниз как список шагов: спросить Steam, забрать оценку
  /// и обложку, убедиться, что игра всё ещё та самая, записать найденное.
  /// Каждый шаг — отдельный метод ниже.
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

    emit(state.copyWith(busy: busyWith(key, value: true)));
    try {
      _replaceGame(game.copyWith(steamLookupAttempted: true), emit);
      // Маркер записан до сети: даже аварийный выход не вызывает повтор.
      await persist();

      final match = await _askSteamAbout(game, event.query);
      if (_closing) return;
      if (match == null) {
        finishBusy(
          emit,
          key,
          message: event.automatic ? null : _l.noticeSteamNothingFound,
        );
        return;
      }

      final reviews = await _steamReviews(match.appId);
      if (_closing) return;
      final coverBytes = await steam.coverBytes(match);
      if (_closing) return;

      var current = _stillSameGame(game);
      if (current == null) {
        finishBusy(emit, key);
        return;
      }

      final previousCover = current.coverPath;
      final coverFile = await _writeSteamCover(game, coverBytes, previousCover);
      final previousShots = current.shotPaths;
      final shotPaths = await _writeSteamShots(game, match);

      // Запись файла — тоже ожидание, и за него игру могли убрать. Свежий
      // файл тогда удаляем: иначе в кэше копились бы обложки-сироты.
      current = _stillSameGame(game);
      if (current == null) {
        await _deleteCoverFile(coverFile?.path);
        await _deleteShotFiles(shotPaths);
        finishBusy(emit, key);
        return;
      }

      final coverPath = coverFile?.path ?? previousCover;
      final rating = _ratingOf(match, reviews);
      final games = [...state.games];
      games[games.indexWhere((g) => g.id == game.id)] = current.copyWith(
        steamAppId: match.appId,
        coverUrl: match.headerImage,
        description: match.description,
        coverPath: coverPath,
        // Пустую подборку не записываем по той же причине, что и пустую
        // оценку: сорвавшаяся загрузка кадров стёрла бы подложку, которая
        // уже показана.
        shotPaths: shotPaths.isEmpty ? current.shotPaths : shotPaths,
        // Пустую оценку не записываем: сорвавшийся запрос стёр бы то, что
        // уже показано, и страница обеднела бы от неудачного обновления.
        rating: rating.hasAnything ? rating : current.rating,
      );
      emit(
        state.copyWith(
          games: games,
          busy: busyWith(key, value: false),
          notice: event.automatic
              ? state.notice
              : notice(_l.noticeSteamFound(match.name)),
        ),
      );
      await persist();

      if (coverPath != previousCover) {
        await _deleteReplacedCover(previousCover);
      }
      if (shotPaths.isNotEmpty) await _deleteShotFiles(previousShots);
      _continueWithSavePaths(game.id, automatic: event.automatic);
    } on Object catch (error) {
      finishBusy(emit, key, message: error.toString(), isError: true);
    }
  }

  /// Спрашивает Steam об игре.
  ///
  /// Идентификатор уже известен — спрашиваем прямо по нему. Поиск по
  /// названию тут не только лишний, но и вреден: он способен ответить
  /// другой игрой.
  Future<SteamGame?> _askSteamAbout(Game game, String? query) =>
      game.steamAppId != null
      ? steam.details(game.steamAppId!)
      : steam.bestMatch(query ?? game.title);

  /// Обзоры — отдельным запросом: в `appdetails` их нет вовсе.
  ///
  /// Своя попытка и свой отказ: промолчи Steam об обзорах, игра всё равно
  /// получит и обложку, и описание, и пути сохранений — терять их из-за
  /// числа рядом с оценкой не за что.
  Future<SteamReviews?> _steamReviews(int appId) async {
    try {
      return await steam.reviews(appId);
    } on Object {
      return null;
    }
  }

  /// Оценка игроков: доля положительных — из обзоров, Metacritic — из тех
  /// же `appdetails`, откуда пришло описание.
  GameRating _ratingOf(SteamGame match, SteamReviews? reviews) => GameRating(
    score: reviews?.score,
    summary: reviews?.summary,
    positive: reviews?.positive ?? 0,
    negative: reviews?.negative ?? 0,
    metacritic: match.metacritic,
  );

  /// Та же ли игра лежит в состоянии, что и до похода в сеть.
  ///
  /// Пока мы ждали ответа, игру могли удалить, а на её место завести
  /// другую с тем же id — у той другой `addedAt`, и чужие метаданные ей
  /// не достаются.
  Game? _stillSameGame(Game game) {
    final current = state.gameById(game.id);
    if (current == null || current.addedAt != game.addedAt) return null;
    return current;
  }

  /// Кладёт обложку из Steam в кэш приложения и возвращает её файл.
  ///
  /// Возвращает null, если писать было нечего или не вышло: из-за картинки
  /// не теряют ни идентификатор, ни описание, ни поиск сейвов. Обложку,
  /// выбранную человеком самим, не трогаем — она лежит вне кэша.
  Future<File?> _writeSteamCover(
    Game game,
    List<int>? bytes,
    String? currentCover,
  ) async {
    final ourOwn = currentCover == null || p.isWithin(_coversDir, currentCover);
    if (bytes == null || !ourOwn) return null;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      p.join(_coversDir, '${safeFileName(game.id)}-$stamp-steam.jpg'),
    );
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on FileSystemException {
      // Ошибка кэша обложки не отменяет ID, описание и поиск сейвов.
      await _deleteCoverFile(file.path);
      return null;
    }
  }

  /// Кладёт кадры из игры в кэш приложения и возвращает их пути.
  ///
  /// Кадров у игры бывает два десятка, берём первые [_maxShots]: подложка
  /// показывает их по кругу, и на пятом обороте человек уже не смотрит, а
  /// каждый следующий — это ещё файл на диске у каждой игры библиотеки.
  ///
  /// Неудача одного кадра не отменяет остальные, а неудача всех не отменяет
  /// ни идентификатор, ни описание: подложка — украшение, и терять из-за
  /// неё метаданные не за что.
  Future<List<String>> _writeSteamShots(Game game, SteamGame match) async {
    final wanted = match.screenshots.take(LibraryBloc._maxShots);
    if (wanted.isEmpty) return const [];

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final written = <String>[];
    var index = 0;
    for (final url in wanted) {
      if (_closing) break;
      final bytes = await steam.imageBytes(url);
      if (bytes == null) continue;
      final file = File(
        p.join(_shotsDir, '${safeFileName(game.id)}-$stamp-$index.jpg'),
      );
      index++;
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        written.add(file.path);
      } on FileSystemException {
        // Один не записавшийся кадр подборку не отменяет.
      }
    }
    return written;
  }

  /// Убирает кадры, которые больше не нужны: заменённые новой подборкой или
  /// осиротевшие, пока мы ходили в сеть. Чужое не трогаем — только свой кэш.
  Future<void> _deleteShotFiles(List<String> paths) async {
    for (final path in paths) {
      if (!p.isWithin(_shotsDir, path)) continue;
      await _deleteCoverFile(path);
    }
  }

  /// Убирает файл обложки, который оказался не нужен. Ошибку удаления
  /// гасим: из-за неубранной картинки не теряют найденные метаданные.
  Future<void> _deleteCoverFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Лишний файл в кэше безвреден, а отменять из-за него нечего.
    }
  }

  /// Убирает обложку, которую только что заменили новой. Трогаем лишь свой
  /// кэш: обложку, выбранную человеком, удалять нельзя — она не наша.
  Future<void> _deleteReplacedCover(String? path) async {
    if (path == null || !p.isWithin(_coversDir, path)) return;
    await _deleteCoverFile(path);
  }

  /// Следующее звено цепочки: по найденному `appid` ищутся пути сохранений.
  void _continueWithSavePaths(String gameId, {required bool automatic}) {
    final updated = state.gameById(gameId);
    if (_closing || updated == null) return;
    if (automatic && updated.savePathsLookupAttempted) return;
    add(SavePathsLookupRequested(updated, automatic: automatic));
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
    emit(state.copyWith(busy: busyWith(key, value: true)));
    try {
      await _steamShortcuts.addGame(
        event.game,
        artwork: await _steamArtwork(event.game),
      );
      emit(
        state.copyWith(
          busy: busyWith(key, value: false),
          notice: notice(_l.noticeSteamAdded(event.game.title)),
        ),
      );
    } on SteamShortcutException catch (error) {
      emit(
        state.copyWith(
          busy: busyWith(key, value: false),
          notice: notice(error.message, isError: true),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: busyWith(key, value: false),
          notice: notice(error.toString(), isError: true),
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
      emit(state.copyWith(notice: notice(_l.noticeMetadataNothingToDo)));
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
      state.copyWith(notice: notice(_l.noticeMetadataRetry(pending.length))),
    );
  }

  /// Спрашивает Steam заново про всю библиотеку.
  ///
  /// Отличие от [_onMetadataRetry] одно, и оно же весь смысл: отбора «чего
  /// не хватает» здесь нет. Приложение прирастает точками данных — сначала
  /// оценка, потом кадры из игры, — а у сложившейся библиотеки нехватки
  /// нет, и прежняя кнопка честно отвечала «метаданные есть у всех».
  /// Подправлять под каждую новую точку отбор значило бы каждый раз
  /// вспоминать об этом месте; проще один раз сходить за всем.
  ///
  /// Название игры и здесь не переписывается, а обложка, выбранная
  /// человеком, остаётся его: за это отвечают те же `_onSteamLookup` и
  /// `_writeSteamCover`, через которые всё и пойдёт.
  Future<void> _onMetadataRefresh(
    MetadataRefreshRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final pending = [
      for (final game in state.games)
        if (game.isInstalled && game.installDir != null) game,
    ];
    if (pending.isEmpty) {
      emit(state.copyWith(notice: notice(_l.noticeMetadataNothingToDo)));
      return;
    }

    // Снимаем оба маркера: игра пойдёт в Steam, а оттуда цепочкой за
    // путями сохранений — тем же порядком, что при добавлении.
    for (final game in pending) {
      _replaceGame(
        game.copyWith(
          steamLookupAttempted: false,
          savePathsLookupAttempted: false,
        ),
        emit,
      );
    }
    await persist();

    // Очередь та же: события идут по одному, залпа по Steam не будет.
    for (final game in pending) {
      final current = state.gameById(game.id);
      if (current == null) continue;
      add(SteamLookupRequested(current, automatic: true));
    }
    emit(
      state.copyWith(notice: notice(_l.noticeMetadataRefresh(pending.length))),
    );
  }

  /// Ход загрузки и разбора базы путей — для указателя в интерфейсе.
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

  /// Подбирает папки сохранений по базе. Уже заданные правила не трогаем:
  /// пользователь мог поправить путь под себя.
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
    emit(state.copyWith(busy: busyWith(key, value: true)));
    // Указатель хода гасим в любом случае: оставшись висеть, он врал бы
    // о продолжающейся работе.
    void done() {
      if (!_closing) add(const SavePathsProgressChanged(null));
    }

    try {
      _replaceGame(game.copyWith(savePathsLookupAttempted: true), emit);
      await persist();
      final found = await _lookupPaths(
        SavePathsLookupRequested(game, refresh: event.refresh),
      );
      if (_closing) return;

      if (found == null) {
        finishBusy(
          emit,
          key,
          message: event.automatic ? null : _l.noticePathsNothingFound,
        );
        done();
        return;
      }

      final current = _stillSameGame(game);
      if (current == null) {
        finishBusy(emit, key);
        done();
        return;
      }

      // Уже заданные пути не трогаем: пользователь мог поправить их под себя.
      final added = current.saveProfile.rulesForNewPaths(found.templates);
      final games = [...state.games];
      games[games.indexWhere((g) => g.id == current.id)] = current.copyWith(
        ludusaviTemplates: found.sourceTemplates,
        ludusaviResolvedPaths: {
          ...current.ludusaviResolvedPaths,
          ...found.templates,
        }.toList(),
        saveProfile: current.saveProfile.copyWith(
          rules: [...current.saveProfile.rules, ...added],
        ),
      );
      emit(
        state.copyWith(
          games: games,
          busy: busyWith(key, value: false),
          notice: event.automatic
              ? state.notice
              : notice(_foundPathsMessage(found, added.length)),
        ),
      );
      await persist();
      done();
    } on Object catch (error) {
      done();
      finishBusy(emit, key, message: error.toString(), isError: true);
    }
  }

  /// Что сказать человеку о найденных путях.
  String _foundPathsMessage(_FoundPaths found, int added) {
    if (found.isEmpty) return _l.noticePathsNothingFound;
    if (added == 0) return _l.noticePathsAlreadySet;
    return found.describe(_l, added);
  }
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

  String describe(L l, int added) {
    final message = l.noticePathsAdded(l.sourceDatabase, added, title);
    if (registryKeys.isEmpty) return message;
    // Реестр мы не переносим, но умолчать о нём нельзя: иначе пользователь
    // решит, что забрал сейв целиком.
    return l.noticeRegistryLeft(message, registryKeys.length);
  }
}
