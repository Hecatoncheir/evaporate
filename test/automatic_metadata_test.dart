import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/launch/library_scanner.dart';
import 'package:evaporate/services/metadata/steam_catalog.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:evaporate/services/saves/ludusavi_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
  );

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
/// Отмеренная пауза здесь не годится. Старую обложку убирают и библиотеку
/// пишут на диск уже после того, как состояние обновилось, а на загруженной
/// машине сборки эта запись не укладывается ни в тридцать миллисекунд, ни в
/// пятьдесят: те же тесты на том же коде проходили в одном прогоне Windows
/// и падали в соседнем. Ожидание по условию от скорости диска не зависит, а
/// не дождавшись — тест всё равно упадёт на своей проверке.
Future<void> _settle(Future<bool> Function() done) async {
  for (var i = 0; i < 250; i++) {
    if (await done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

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

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late _Steam steam;
  late _Paths catalog;
  late LibraryBloc library;

  LibraryBloc open() => LibraryBloc(
    paths: paths,
    settings: settings,
    steam: steam,
    savePaths: catalog,
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
  });

  tearDown(() async {
    await library.close();
    await settings.close();
    await tmp.delete(recursive: true);
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
          s.gameById('game')?.savePathsLookupAttempted == true &&
          !s.isBusy(LibraryBloc.savePathsKey('game')) &&
          !s.isBusy(LibraryBloc.steamKey('game')),
    );
    await library.persist();
    return library.state.gameById('game')!;
  }

  Future<void> reopen() async {
    await library.close();
    library = open();
    library.add(const LibraryLoadRequested());
    await _wait(library, (s) => s.loaded);
    // Дать событиям, поставленным загрузкой в очередь, обработаться.
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  test(
    'local addition saves Steam metadata, image and future paths once',
    () async {
      final stale = await add();
      final game = await complete();
      expect(game.steamAppId, 42);
      expect(game.description, 'An example game');
      expect(game.coverUrl, steam.result!.headerImage);
      expect(await File(game.coverPath!).readAsBytes(), [1, 2, 3]);
      expect(game.ludusaviTemplates, ['{GAME}/profiles/*/saves']);
      expect(game.saveProfile.rules, isEmpty);
      expect(catalog.lastId, 42);
      library.add(GameUpdated(stale.copyWith(notes: 'edited')));
      await _wait(library, (s) => s.gameById('game')?.notes == 'edited');
      await reopen();
      final loaded = library.state.gameById('game')!;
      expect(loaded.steamLookupAttempted, isTrue);
      expect(loaded.savePathsLookupAttempted, isTrue);
      expect(loaded.steamAppId, 42);
      expect(loaded.ludusaviTemplates, game.ludusaviTemplates);
      expect(await File(loaded.coverPath!).exists(), isTrue);
      expect(steam.calls, 1);
      expect(steam.covers, 1);
      expect(catalog.loads, 1);
      expect(catalog.lookups, 1);
    },
  );

  test(
    'download completion starts enrichment with release name, not before',
    () async {
      final queued = await add(status: GameStatus.downloading);
      expect(steam.calls, 0);
      library.add(
        GameUpdated(
          queued.copyWith(status: GameStatus.installed),
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
    await _settle(() async => steam.calls >= 1);

    // Первый запрос ещё висит — значит, остальные не ушли следом.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(steam.calls, 1);

    // Отпускаем — очередь двигается дальше.
    steam.pending!.complete(null);
    steam.pending = null;
    await _settle(() async => steam.calls >= 5);
    expect(steam.calls, 5);
    expect(library.state.games.every((g) => g.steamLookupAttempted), isTrue);
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
    expect(library.state.gameById('game')!.steamLookupAttempted, isTrue);

    steam.fail = false;
    library.add(const MetadataRetryRequested());
    await complete();

    expect(steam.calls, 2);
    expect(library.state.gameById('game')!.steamAppId, 42);
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
      (s) => s.gameById('game')?.coverPath != null,
    );

    expect(game.steamAppId, 42);
    expect(steam.covers, 1);
    expect(await File(game.coverPath!).exists(), isTrue);
    // Название из библиотеки не трогаем: его задавал человек или манифест.
    expect(game.title, 'Из манифеста');
  });

  test('failed Steam request survives restart; manual request retries both catalogs', () async {
    steam.fail = true;
    await add();
    await _wait(
      library,
      (s) =>
          s.notice?.isError == true && !s.isBusy(LibraryBloc.steamKey('game')),
    );
    await reopen();
    expect(steam.calls, 1);
    expect(catalog.loads, 0);
    steam.fail = false;
    library.add(SteamLookupRequested(library.state.gameById('game')!));
    await complete();
    expect(steam.calls, 2);
    expect(catalog.loads, 1);
  });

  test(
    'manual refresh replaces cached art without enabling automatic retries',
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
        (s) => s.gameById('game')?.description == 'Updated description',
      );
      // Ждать надо последнего звена, а не первого: за уборкой старой обложки
      // в обработчике идёт ещё запрос путей сохранений, и он-то и поднимает
      // счётчик каталога. Уборку одну дождаться мало — проверка ниже успеет
      // спросить каталог до того, как его спросит приложение.
      await _settle(
        () async =>
            steam.calls >= 2 &&
            catalog.loads >= 2 &&
            !await File(original.coverPath!).exists(),
      );
      final updated = library.state.gameById('game')!;
      expect(updated.coverPath, isNot(original.coverPath));
      expect(await File(updated.coverPath!).exists(), isTrue);
      expect(await File(original.coverPath!).exists(), isFalse);
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
      await reopen();
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
    },
  );

  test('no Steam match is also remembered', () async {
    steam.result = null;
    await add();
    await _wait(
      library,
      (s) =>
          s.gameById('game')!.steamLookupAttempted &&
          !s.isBusy(LibraryBloc.steamKey('game')),
    );
    await reopen();
    expect(steam.calls, 1);
    expect(catalog.loads, 0);
  });

  test(
    'failed manifest request is not retried until user requests it',
    () async {
      catalog.fail = true;
      await add();
      await complete();
      await reopen();
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
      catalog.fail = false;
      library.add(
        SavePathsLookupRequested(
          library.state.gameById('game')!,
          refresh: true,
        ),
      );
      await _wait(
        library,
        (s) =>
            s.gameById('game')!.ludusaviTemplates.isNotEmpty &&
            !s.isBusy(LibraryBloc.savePathsKey('game')),
      );
      expect(catalog.loads, 2);
      expect(catalog.refreshed, isTrue);
      expect(steam.calls, 1);
    },
  );

  test('missing manifest entry is remembered across restarts', () async {
    catalog.result = null;
    await add();
    await complete();
    await reopen();
    expect(catalog.lookups, 1);
    expect(catalog.loads, 1);
  });

  test(
    'future wildcard path resolves before snapshot without catalog access',
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
      library.add(SnapshotRequested(game));
      await _wait(library, (s) => (s.snapshots['game'] ?? []).isNotEmpty);
      expect(
        library.state.gameById('game')!.saveProfile.rules.single.template,
        contains('player/saves'),
      );
      expect(library.state.snapshots['game']!.single.fileCount, 1);
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );

  test(
    'removal clears cached cover; new library membership searches again',
    () async {
      final stale = await add();
      final game = await complete();
      library.add(GameRemoved(stale));
      await _wait(library, (s) => s.games.isEmpty);
      await _settle(() async => !await File(game.coverPath!).exists());
      expect(await File(game.coverPath!).exists(), isFalse);
      await add();
      await complete();
      expect(steam.calls, 2);
      expect(catalog.loads, 2);
    },
  );

  test('late Steam response cannot resurrect a removed game', () async {
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
    'cover filesystem failure does not lose ID or block save path lookup',
    () async {
      await Directory(paths.dataDir).create(recursive: true);
      await File(paths.coversDir).writeAsString('not a directory');
      await add();
      final game = await complete();
      expect(game.steamAppId, 42);
      expect(game.description, 'An example game');
      expect(game.coverPath, isNull);
      expect(catalog.lastId, 42);
    },
  );

  test('scanned installations join the same enrichment pipeline', () async {
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

  test('concurrent manifest loads share one download; known ID never falls back to title', () async {
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

  test(
    'stale updates retain concrete catalog paths and attempt markers',
    () async {
      catalog.result = const LudusaviEntry(
        title: 'Example',
        steamId: 42,
        templates: ['{GAME}/saves'],
      );
      final stale = await add();
      await complete();
      library.add(GameUpdated(stale.copyWith(notes: 'stale edit')));
      await _wait(library, (s) => s.gameById('game')?.notes == 'stale edit');
      await reopen();
      final game = library.state.gameById('game')!;
      expect(game.saveProfile.rules.single.template, '{GAME}/saves');
      expect(game.ludusaviResolvedPaths, ['{GAME}/saves']);
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );

  test(
    'manually removed catalog rules are not restored by a local snapshot',
    () async {
      catalog.result = const LudusaviEntry(
        title: 'Example',
        steamId: 42,
        templates: ['{GAME}/saves'],
      );
      await add();
      final game = await complete();
      library.add(GameUpdated(game.copyWith(saveProfile: const SaveProfile())));
      await _wait(
        library,
        (s) => s.gameById('game')!.saveProfile.rules.isEmpty,
      );
      library.add(SnapshotRequested(library.state.gameById('game')!));
      await _wait(
        library,
        (s) =>
            s.notice?.isError == true &&
            !s.isBusy(LibraryBloc.snapshotKey('game')),
      );
      expect(library.state.gameById('game')!.saveProfile.rules, isEmpty);
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );

  test(
    'duplicate automatic events during a request do not contact catalogs twice',
    () async {
      steam.pending = Completer<SteamGame?>();
      final game = await add();
      library.add(SteamLookupRequested(game, automatic: true));
      library.add(GameUpdated(game));
      // Отметку занятости первый запрос ставит до записи на диск, а повтор
      // отскакивает от неё сразу — значит, к моменту первого обращения к
      // каталогу повтор уже отработал и второго обращения не будет.
      await _settle(() async => steam.calls > 0);
      expect(steam.calls, 1);
      steam.pending!.complete(steam.result);
      await complete();
      library.add(SavePathsLookupRequested(game, automatic: true));
      await reopen();
      expect(steam.calls, 1);
      expect(catalog.loads, 1);
    },
  );
}
