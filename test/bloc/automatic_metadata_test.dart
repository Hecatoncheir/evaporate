import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/library_scanner.dart';
import 'package:evaporate/services/metadata/steam_catalog.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:evaporate/services/saves/ludusavi_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/library_seed.dart';
import '../support/pump_until.dart';
import '../support/temp_dir.dart';

class _Steam extends SteamCatalog {
  int calls = 0;
  int covers = 0;
  String? query;
  bool fail = false;
  Completer<SteamGame?>? pending;
  SteamGame? result = const SteamGame(
    appId: 42,
    name: 'Example',
    description: 'An example game',
    headerImage: 'https://example.invalid/header.jpg',
    metacritic: 86,
    screenshots: [
      'https://example.invalid/ss0.jpg',
      'https://example.invalid/ss1.jpg',
    ],
  );

  int reviewCalls = 0;
  bool reviewsFail = false;
  SteamReviews? reviewsResult = const SteamReviews(
    score: 8,
    summary: 'Очень положительные',
    positive: 90,
    negative: 10,
  );

  @override
  Future<SteamReviews?> reviews(int appId) async {
    reviewCalls++;
    if (reviewsFail) throw const SocketException('offline');
    return reviewsResult;
  }

  @override
  Future<SteamGame?> bestMatch(
    String releaseName, {
    double minSimilarity = 0.6,
  }) async {
    calls++;
    query = releaseName;
    if (fail) throw const SocketException('offline');
    return pending == null ? result : pending!.future;
  }

  /// Подробности по известному идентификатору.
  ///
  /// Когда `appid` уже известен — например, пришёл из манифеста Steam с
  /// диска, — приложение спрашивает по нему, а не ищет по названию: поиск
  /// тут не только лишний, но и способен ответить другой игрой.
  @override
  Future<SteamGame?> details(int appId) async {
    calls++;
    if (fail) throw const SocketException('offline');
    return pending == null ? result : pending!.future;
  }

  @override
  Future<List<int>?> coverBytes(SteamGame game) async {
    covers++;
    return [1, 2, 3];
  }

  /// Кадры качаются по одному через общий загрузчик картинок.
  int shots = 0;

  @override
  Future<List<int>?> imageBytes(String url) async {
    shots++;
    return [4, 5, 6];
  }
}

class _Paths extends LudusaviCatalog {
  _Paths(String cacheFile) : super(cacheFile: cacheFile);

  int loads = 0;
  int lookups = 0;
  int? lastId;
  bool fail = false;
  bool refreshed = false;
  LudusaviEntry? result = const LudusaviEntry(
    title: 'Different catalog title',
    steamId: 42,
    templates: ['{GAME}/profiles/*/saves'],
  );

  @override
  Future<bool> ensureLoaded({bool refresh = false}) async {
    loads++;
    refreshed = refresh;
    if (fail) throw const SocketException('offline');
    return true;
  }

  @override
  LudusaviEntry? find({required String title, int? steamAppId}) {
    lookups++;
    lastId = steamAppId;
    return result;
  }
}

/// Ждёт, пока условие исполнится, — не дольше пяти секунд.
///
/// Ждёт игру, удовлетворяющую условию, и возвращает её.
Future<Game> _waitFor(
  LibraryBloc bloc,
  bool Function(LibraryState) predicate,
) async {
  await _wait(bloc, predicate);
  return bloc.state.gameById('game')!;
}

Future<void> _wait(
  LibraryBloc bloc,
  bool Function(LibraryState) predicate,
) async {
  if (predicate(bloc.state)) return;
  await bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
}

Future<void> _waitSaves(
  SavesBloc bloc,
  bool Function(SavesState) predicate,
) async {
  if (predicate(bloc.state)) return;
  await bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
}

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late _Steam steam;
  late _Paths catalog;
  late LibraryBloc library;
  late SavesBloc saves;

  LibraryBloc open() => LibraryBloc(
    paths: paths,
    settings: settings,
    steam: steam,
    savePaths: catalog,
  );

  SavesBloc openSaves() => SavesBloc(
    paths: paths,
    library: library,
    settings: settings,
    saveRoots: () => [],
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_metadata_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    steam = _Steam();
    catalog = _Paths(paths.savePathsCacheFile);
    library = open();
    saves = openSaves();
  });

  tearDown(() async {
    await saves.close();
    await library.close();
    await settings.close();
    await deleteTempDir(tmp);
  });

  Future<Game> add({GameStatus status = GameStatus.installed}) async {
    library.add(
      GameAdded(
        id: 'game',
        title: 'Example',
        installDir: paths.defaultInstallDir,
        status: status,
      ),
    );
    await _wait(library, (s) => s.gameById('game') != null);
    return library.state.gameById('game')!;
  }

  Future<Game> complete() async {
    await _wait(
      library,
      (s) =>
          s.gameById('game')?.saveDiscovery.savePathsLookupAttempted == true &&
          !s.isBusy(LibraryBloc.savePathsKey('game')) &&
          !s.isBusy(LibraryBloc.steamKey('game')),
    );
    await library.persist();
    return library.state.gameById('game')!;
  }

  Future<void> reopen() async {
    await saves.close();
    await library.close();
    library = open();
    saves = openSaves();
    library.add(const LibraryLoadRequested());
    saves.add(const SavesLoadRequested());
    await _wait(library, (s) => s.loaded);
    // Дать событиям, поставленным загрузкой в очередь, обработаться.
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  test(
    'добавленная вручную игра один раз забирает данные, обложку и пути',
    () async {
      await add();
      final game = await complete();
      expect(game.details.steamAppId, 42);
      expect(game.details.description, 'An example game');
      expect(game.details.coverUrl, steam.result!.headerImage);
      expect(await File(game.details.coverPath!).readAsBytes(), [1, 2, 3]);
      expect(game.saveDiscovery.ludusaviTemplates, ['{GAME}/profiles/*/saves']);
      expect(game.saveProfile.rules, isEmpty);
      expect(catalog.lastId, 42);
      library.add(const GameExecutableSet('game', '/games/example.exe'));
      await _wait(
        library,
        (s) => s.gameById('game')?.executablePath == '/games/example.exe',
      );
      await reopen();
      final loaded = library.state.gameById('game')!;
      expect(loaded.details.steamLookupAttempted, isTrue);
      expect(loaded.saveDiscovery.savePathsLookupAttempted, isTrue);
      expect(loaded.details.steamAppId, 42);
      expect(
        loaded.saveDiscovery.ludusaviTemplates,
        game.saveDiscovery.ludusaviTemplates,
      );
      expect(await File(loaded.details.coverPath!).exists(), isTrue);
      expect(steam.calls, 1);
      expect(steam.covers, 1);
      expect(catalog.loads, 1);
      expect(catalog.lookups, 1);
    },
  );

  test(
    'поиск начинается по имени раздачи, когда загрузка закончилась',
    () async {
      final queued = await add(status: GameStatus.downloading);
      expect(steam.calls, 0);
      library.add(
        GameDownloadFinished(
          queued.id,
          installDir: queued.installDir!,
          sizeBytes: 0,
          metadataQuery: 'Example.Release',
        ),
      );
      await complete();
      expect(steam.query, 'Example.Release');
      expect(steam.calls, 1);
      expect(catalog.lastId, 42);
    },
  );

  // Загрузка библиотеки ставит поиск метаданных каждой игре сразу, а Bloc
  // по умолчанию обрабатывает события параллельно. Сорок игр давали сорок
  // одновременных соединений со Steam, каждое со своим HttpClient, — залп,
  // на который Steam отвечает отказом. А маркер «уже пробовали» к тому
  // моменту записан, и без обложек игры остаются навсегда.
  test('поиск метаданных идёт по одной игре, а не залпом', () async {
    steam.pending = Completer<SteamGame?>();
    for (var i = 0; i < 5; i++) {
      library.add(
        GameAdded(
          id: 'game-$i',
          title: 'Игра $i',
          installDir: paths.defaultInstallDir,
          status: GameStatus.installed,
        ),
      );
    }
    await _wait(library, (s) => s.games.length == 5);
    // Счётчик живёт в подделке, а не в состоянии, поэтому ждём опросом,
    // а не подпиской на поток: нужного состояния может уже не прийти.
    await waitUntil(() async => steam.calls >= 1);

    // Первый запрос ещё висит — значит, остальные не ушли следом.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(steam.calls, 1);

    // Отпускаем — очередь двигается дальше.
    steam.pending!.complete(null);
    steam.pending = null;
    await waitUntil(() async => steam.calls >= 5);
    expect(steam.calls, 5);
    expect(
      library.state.games.every((g) => g.details.steamLookupAttempted),
      isTrue,
    );
  });

  // Автоматически маркер «уже пробовали» не снимается никогда — иначе
  // приложение при каждом запуске ходило бы в Steam за играми, которых там
  // нет. Но первый запуск мог прийтись на офлайн, и тогда без обложек
  // осталась вся библиотека сразу, а кнопка есть только у отдельной игры.
  test('«поискать для всех» повторяет то, что не вышло', () async {
    steam.fail = true;
    await add();
    await _wait(
      library,
      (s) =>
          s.notice?.isError == true && !s.isBusy(LibraryBloc.steamKey('game')),
    );
    expect(steam.calls, 1);
    expect(
      library.state.gameById('game')!.details.steamLookupAttempted,
      isTrue,
    );

    steam.fail = false;
    library.add(const MetadataRetryRequested());
    await complete();

    expect(steam.calls, 2);
    expect(library.state.gameById('game')!.details.steamAppId, 42);
  });

  test('«поискать для всех» молчит, когда искать нечего', () async {
    await add();
    await complete();
    final before = steam.calls;

    library.add(const MetadataRetryRequested());
    await _wait(
      library,
      (s) => s.notice?.message.contains('Метаданные есть') ?? false,
    );

    expect(steam.calls, before);
  });

  // Игру, поставленную Steam, приложение опознаёт по манифесту на диске:
  // идентификатор приходит вместе с папкой. Искать её по названию после
  // этого незачем, а обложка нужна ровно так же — без неё в сетке
  // остаётся безымянный прямоугольник.
  test('игра с известным appid получает обложку, минуя поиск', () async {
    library.add(
      GameAdded(
        id: 'game',
        title: 'Из манифеста',
        installDir: paths.defaultInstallDir,
        status: GameStatus.installed,
        steamAppId: 42,
      ),
    );

    final game = await _waitFor(
      library,
      (s) => s.gameById('game')?.details.coverPath != null,
    );

    expect(game.details.steamAppId, 42);
    expect(steam.covers, 1);
    expect(await File(game.details.coverPath!).exists(), isTrue);
    // Название из библиотеки не трогаем: его задавал человек или манифест.
    expect(game.title, 'Из манифеста');
  });

  group('оценка игры', () {
    test('подпись, счётчики и оценка прессы доезжают до карточки', () async {
      await add();
      final game = await complete();

      final rating = game.details.rating!;
      expect(rating.summary, 'Очень положительные');
      expect(rating.positive, 90);
      expect(rating.negative, 10);
      expect(rating.positiveShare, 90);
      expect(rating.metacritic, 86);
      expect(steam.reviewCalls, 1);
    });

    // Обзоры спрашиваются отдельным запросом, и его отказ — не повод
    // оставить игру без обложки, описания и путей сохранений.
    test('молчание об обзорах не отменяет остальные метаданные', () async {
      steam.reviewsFail = true;
      await add();
      final game = await complete();

      expect(game.details.description, 'An example game');
      expect(game.details.coverPath, isNotNull);
      expect(game.details.rating!.total, 0);
      expect(game.details.rating!.metacritic, 86);
    });

    // Библиотека складывалась до того, как появились обзоры: у её игр
    // пройдена вся цепочка, и без отдельной ветки в отборе кнопка
    // «Обновить метаданные» отвечала бы «есть у всех», а оценку пришлось бы
    // добывать по одной игре на её странице.
    test(
      'кнопка обновления доводит оценку до игры, где всё остальное есть',
      () async {
        await add();
        final ready = await complete();
        expect(ready.details.steamAppId, isNotNull);
        expect(ready.saveDiscovery.savePathsLookupAttempted, isTrue);

        // Такой игра пришла бы из библиотеки, записанной прежней версией.
        await seedGame(
          library,
          paths,
          ready.copyWith(details: ready.details.copyWith(rating: null)),
        );

        library.add(const MetadataRetryRequested());
        await _wait(library, (s) => s.gameById('game')?.details.rating != null);

        expect(library.state.gameById('game')!.details.rating!.positive, 90);
      },
    );

    // Неудачное обновление не должно обеднять страницу: было что
    // показать — пусть и остаётся, пока не появится новое.
    test('пустой ответ не стирает уже показанную оценку', () async {
      await add();
      final first = await complete();
      expect(first.details.rating!.positive, 90);

      steam.reviewsResult = null;
      steam.result = const SteamGame(
        appId: 42,
        name: 'Example',
        description: 'Updated description',
      );
      library.add(SteamLookupRequested(first));
      await _wait(
        library,
        (s) => s.gameById('game')?.details.description == 'Updated description',
      );

      final second = library.state.gameById('game')!;
      expect(second.details.rating!.positive, 90);
      expect(second.details.rating!.metacritic, 86);
    });
  });

  test(
    'сорвавшийся поиск помнится и после перезапуска, а ручной пробует снова',
    () async {
      steam.fail = true;
      await add();
      await _wait(
        library,
        (s) =>
            s.notice?.isError == true &&
            !s.isBusy(LibraryBloc.steamKey('game')),
      );
      await reopen();
      expect(steam.calls, 1);
      expect(catalog.loads, 0);
      steam.fail = false;
      library.add(SteamLookupRequested(library.state.gameById('game')!));
      await complete();
      expect(steam.calls, 2);
      expect(catalog.loads, 1);
    },
  );

  test(
    'ручное обновление меняет обложку, не включая автоматических повторов',
    () async {
      await add();
      final original = await complete();
      steam.result = const SteamGame(
        appId: 42,
        name: 'Example',
        description: 'Updated description',
      );
      library.add(SteamLookupRequested(original));
      await _wait(
        library,
        (s) => s.gameById('game')?.details.description == 'Updated description',
      );
      // Ждать надо последнего звена, а не первого: за уборкой старой обложки
      // в обработчике идёт ещё запрос путей сохранений, и он-то и поднимает
      // счётчик каталога. Уборку одну дождаться мало — проверка ниже успеет
      // спросить каталог до того, как его спросит приложение.
      await waitUntil(
        () async =>
            steam.calls >= 2 &&
            catalog.loads >= 2 &&
            !await File(original.details.coverPath!).exists(),
      );
      final updated = library.state.gameById('game')!;
      expect(updated.details.coverPath, isNot(original.details.coverPath));
      expect(await File(updated.details.coverPath!).exists(), isTrue);
      expect(await File(original.details.coverPath!).exists(), isFalse);
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
      await reopen();
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
    },
  );

  test('«в Steam не нашлось» — тоже ответ, и он помнится', () async {
    steam.result = null;
    await add();
    await _wait(
      library,
      (s) =>
          s.gameById('game')!.details.steamLookupAttempted &&
          !s.isBusy(LibraryBloc.steamKey('game')),
    );
    await reopen();
    expect(steam.calls, 1);
    expect(catalog.loads, 0);
  });

  test('сорвавшийся запрос базы путей сам не повторяется', () async {
    catalog.fail = true;
    await add();
    await complete();
    await reopen();
    expect(steam.calls, 1);
    expect(catalog.loads, 1);
    catalog.fail = false;
    library.add(
      SavePathsLookupRequested(library.state.gameById('game')!, refresh: true),
    );
    await _wait(
      library,
      (s) =>
          s.gameById('game')!.saveDiscovery.ludusaviTemplates.isNotEmpty &&
          !s.isBusy(LibraryBloc.savePathsKey('game')),
    );
    expect(catalog.loads, 2);
    expect(catalog.refreshed, isTrue);
    expect(steam.calls, 1);
  });

  test('«в базе путей игры нет» переживает перезапуск', () async {
    catalog.result = null;
    await add();
    await complete();
    await reopen();
    expect(catalog.lookups, 1);
    expect(catalog.loads, 1);
  });

  test(
    'путь с подстановкой разворачивается перед снимком, не трогая базу',
    () async {
      await add();
      final game = await complete();
      final save = File(
        p.join(
          paths.defaultInstallDir,
          'profiles',
          'player',
          'saves',
          'slot.dat',
        ),
      );
      await save.parent.create(recursive: true);
      await save.writeAsString('progress');
      saves.add(SnapshotRequested(game));
      await _waitSaves(saves, (s) => (s.snapshots['game'] ?? []).isNotEmpty);
      expect(
        library.state.gameById('game')!.saveProfile.rules.single.template,
        contains('player/saves'),
      );
      expect(saves.state.snapshots['game']!.single.fileCount, 1);
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );

  test(
    'удаление уносит обложку, а заведённая заново игра ищется сызнова',
    () async {
      final stale = await add();
      final game = await complete();
      library.add(GameRemoved(stale));
      await _wait(library, (s) => s.games.isEmpty);
      await waitUntil(
        () async => !await File(game.details.coverPath!).exists(),
      );
      expect(await File(game.details.coverPath!).exists(), isFalse);
      await add();
      await complete();
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
    },
  );

  test('запоздавший ответ Steam не воскрешает удалённую игру', () async {
    steam.pending = Completer<SteamGame?>();
    final game = await add();
    await _wait(library, (s) => s.isBusy(LibraryBloc.steamKey('game')));
    library.add(GameRemoved(game));
    await _wait(library, (s) => s.games.isEmpty);
    steam.pending!.complete(steam.result);
    await _wait(library, (s) => !s.isBusy(LibraryBloc.steamKey('game')));
    expect(library.state.games, isEmpty);
    expect(catalog.loads, 0);
    expect(await Directory(paths.coversDir).exists(), isFalse);
  });

  test(
    'сбой записи обложки не теряет appid и не отменяет поиск путей',
    () async {
      await Directory(paths.dataDir).create(recursive: true);
      await File(paths.coversDir).writeAsString('not a directory');
      await add();
      final game = await complete();
      expect(game.details.steamAppId, 42);
      expect(game.details.description, 'An example game');
      expect(game.details.coverPath, isNull);
      expect(catalog.lastId, 42);
    },
  );

  test('найденные на диске игры идут той же цепочкой', () async {
    final exe = File(
      p.join(
        paths.defaultInstallDir,
        'Example',
        Platform.isWindows ? 'game.exe' : 'game.sh',
      ),
    );
    await exe.parent.create(recursive: true);
    await exe.writeAsBytes([77, 90]);
    final found = await LibraryScanner.scan(paths.defaultInstallDir);
    expect(found, hasLength(1));
    final candidate = found.single;
    library.add(
      GameAdded(
        id: 'game',
        title: candidate.title,
        installDir: candidate.installDir,
        executablePath: candidate.executablePath,
        status: GameStatus.installed,
        source: GameSource(
          kind: GameSourceKind.localFolder,
          value: candidate.installDir,
        ),
      ),
    );
    await complete();
    expect(steam.calls, 1);
    expect(catalog.lastId, 42);
    expect(
      await LibraryScanner.scan(
        paths.defaultInstallDir,
        existingDirs: LibraryScanner.installedDirs(library.state.games),
      ),
      isEmpty,
    );
  });

  test('одновременные запросы базы качают её один раз, а известный appid не ищут по названию', () async {
    var fetches = 0;
    final source = Completer<String>();
    final real = LudusaviCatalog(
      cacheFile: paths.savePathsCacheFile,
      fetch: (_) {
        fetches++;
        return source.future;
      },
    );
    final one = real.ensureLoaded();
    final two = real.ensureLoaded();
    source.complete('''
Example:
  steam:
    id: 42
  files:
    <base>/saves:
      tags: [save]
''');
    await Future.wait([one, two]);
    expect(fetches, 1);
    expect(real.find(title: 'Example', steamAppId: 99), isNull);
    expect(real.find(title: 'Different', steamAppId: 42)!.templates, [
      '{GAME}/saves',
    ]);
    expect(real.find(title: 'Example')!.steamId, 42);
  });

  // Правка, отправленная человеком, пока шёл поиск, прежде несла игру
  // целиком — такой, какой её захватили до ответа каталога, — и стирала
  // найденные пути, отметки и оценку. Теперь правка называет, что меняется.
  test(
    'правка после поиска не стирает найденные пути, отметки и оценку',
    () async {
      catalog.result = const LudusaviEntry(
        title: 'Example',
        steamId: 42,
        templates: ['{GAME}/saves'],
      );
      await add();
      await complete();
      library
        ..add(const GameExecutableSet('game', '/games/example.exe'))
        ..add(const AutoSnapshotChanged('game', onLaunch: true));
      await _wait(
        library,
        (s) => s.gameById('game')!.saveProfile.autoSnapshotOnLaunch,
      );
      expect(library.state.gameById('game')!.details.rating, isNotNull);
      await reopen();
      final game = library.state.gameById('game')!;
      expect(game.saveProfile.rules.single.template, '{GAME}/saves');
      expect(game.saveDiscovery.ludusaviResolvedPaths, ['{GAME}/saves']);
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );

  test('убранное человеком правило не возвращается со снимком', () async {
    catalog.result = const LudusaviEntry(
      title: 'Example',
      steamId: 42,
      templates: ['{GAME}/saves'],
    );
    await add();
    final game = await complete();
    for (final rule in game.saveProfile.rules) {
      library.add(SaveRuleRemoved(game.id, rule.id));
    }
    await _wait(library, (s) => s.gameById('game')!.saveProfile.rules.isEmpty);
    saves.add(SnapshotRequested(library.state.gameById('game')!));
    await _waitSaves(
      saves,
      (s) =>
          s.notice?.isError == true && !s.isBusy(SavesBloc.snapshotKey('game')),
    );
    expect(library.state.gameById('game')!.saveProfile.rules, isEmpty);
    expect(steam.calls, 1);
    expect(catalog.loads, 1);
  });

  test('повторное событие во время поиска второго запроса не делает', () async {
    steam.pending = Completer<SteamGame?>();
    final game = await add();
    library.add(SteamLookupRequested(game, automatic: true));
    library.add(SteamLookupRequested(game, automatic: true));
    // Отметку занятости первый запрос ставит до записи на диск, а повтор
    // отскакивает от неё сразу — значит, к моменту первого обращения к
    // каталогу повтор уже отработал и второго обращения не будет.
    await waitUntil(() async => steam.calls > 0);
    expect(steam.calls, 1);
    steam.pending!.complete(steam.result);
    await complete();
    library.add(SavePathsLookupRequested(game, automatic: true));
    await reopen();
    expect(steam.calls, 1);
    expect(catalog.loads, 1);
  });

  test('кадры из игры сохраняются рядом с обложкой', () async {
    await add();
    final game = await complete();

    expect(steam.shots, 2);
    expect(game.details.shotPaths, hasLength(2));
    for (final shot in game.details.shotPaths) {
      expect(p.isWithin(paths.shotsDir, shot), isTrue, reason: shot);
      expect(await File(shot).readAsBytes(), [4, 5, 6]);
    }

    // Пути переживают перезапуск: подложка не должна пропадать оттого, что
    // приложение закрыли.
    await reopen();
    expect(
      library.state.gameById('game')!.details.shotPaths,
      game.details.shotPaths,
    );
  });

  test(
    'игра без кадров в Steam остаётся без подложки, но с метаданными',
    () async {
      steam.result = const SteamGame(
        appId: 42,
        name: 'Example',
        description: 'An example game',
      );
      await add();
      final game = await complete();

      expect(game.details.shotPaths, isEmpty);
      expect(steam.shots, 0);
      expect(game.details.steamAppId, 42);
      expect(game.details.description, 'An example game');
    },
  );

  test('удаление игры уносит её кадры с диска', () async {
    await add();
    final game = await complete();
    final shots = [for (final path in game.details.shotPaths) File(path)];
    expect(shots, hasLength(2));

    library.add(GameRemoved(game));
    await waitUntil(() async {
      for (final file in shots) {
        if (await file.exists()) return false;
      }
      return true;
    });
    for (final file in shots) {
      expect(await file.exists(), isFalse, reason: file.path);
    }
  });

  test(
    '«обновить всё» идёт в Steam за игрой, у которой всё на месте',
    () async {
      await add();
      await complete();
      expect(steam.calls, 1);

      // Прежняя кнопка на такой библиотеке честно отвечает «всё на месте»:
      // цепочка пройдена до конца, и нехватки у игры нет.
      library.add(const MetadataRetryRequested());
      await _wait(library, (s) => s.notice != null);
      expect(steam.calls, 1);

      library.add(const MetadataRefreshRequested());
      await waitUntil(() async => steam.calls > 1);
      expect(steam.calls, 2);
      await complete();
      // Маркеры снова проставлены — обновление не оставило библиотеку в
      // состоянии «сходим ещё раз при следующем запуске».
      final game = library.state.gameById('game')!;
      expect(game.details.steamLookupAttempted, isTrue);
      expect(game.saveDiscovery.savePathsLookupAttempted, isTrue);
    },
  );
}
