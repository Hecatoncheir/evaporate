import 'dart:convert';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/launch/game_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late SavesBloc saves;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_bloc_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      // Выход из игры запускает обход папок в поисках следов её работы.
      // Настоящие «Документы» и AppData в тесте обходить нечего.
      saveRoots: () => const [],
    );
  });

  tearDown(() async {
    // Обработчики пишут состояние уже после `emit`, а тест дожидается
    // именно состояния. Своя запись встаёт в ту же очередь и тем самым
    // дожидается чужих — иначе они настигнут нас во время удаления папки.
    if (!saves.isClosed) await saves.close();
    if (!library.isClosed) {
      await library.persist();
      await library.close();
    }
    await settings.close();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  /// События обрабатываются асинхронно, поэтому ждём нужное состояние,
  /// а не полагаемся на то, что оно наступило сразу после `add`.
  Future<LibraryState> waitFor(bool Function(LibraryState) condition) {
    if (condition(library.state)) return Future.value(library.state);
    return library.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 5));
  }

  Future<SavesState> waitForSaves(bool Function(SavesState) condition) {
    if (condition(saves.state)) return Future.value(saves.state);
    return saves.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 5));
  }

  String addGame(String title) {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: title));
    return id;
  }

  test(
    'добавленная игра попадает в состояние и переживает перезагрузку',
    () async {
      final id = addGame('Игра');
      await waitFor((s) => s.gameById(id) != null);

      expect(library.state.games, hasLength(1));
      expect(library.state.gameById(id)?.title, 'Игра');

      await library.persist();
      final reopened = LibraryBloc(
        automaticMetadata: false,
        paths: paths,
        settings: settings,
      );
      reopened.add(const LibraryLoadRequested());
      await reopened.stream.firstWhere((s) => s.loaded);

      expect(reopened.state.games.map((g) => g.title), ['Игра']);
      await reopened.close();
    },
  );

  // Идентификатор задачи звался `downloadGid` во времена aria2, где gid —
  // родное имя. Библиотеки, записанные до переименования, лежат у людей на
  // дисках, и незнакомый ключ молча оборвал бы связь игры с её загрузкой:
  // качается, а к какой игре — неизвестно.
  test('библиотека со старым ключом downloadGid не теряет загрузку', () async {
    await Directory(paths.dataDir).create(recursive: true);
    await File(paths.libraryFile).writeAsString(
      jsonEncode({
        'version': 1,
        'games': [
          {
            'id': 'game-1',
            'title': 'Игра из прошлой версии',
            'addedAt': DateTime.now().toIso8601String(),
            'status': 'downloading',
            'downloadGid': 'task-7',
          },
        ],
      }),
    );

    library.add(const LibraryLoadRequested());
    await waitFor((s) => s.loaded);

    expect(library.state.gameById('game-1')?.downloadTaskId, 'task-7');
  });

  test('идентификатор задачи записывается под новым именем', () async {
    final id = addGame('Игра');
    final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

    final json = game.copyWith(downloadTaskId: 'task-7').toJson();

    expect(json['downloadTaskId'], 'task-7');
    expect(json.containsKey('downloadGid'), isFalse);
  });

  test('метаданные Steam переживают запись и чтение', () async {
    final game = Game(
      id: 'steam-game',
      title: 'Игра',
      addedAt: DateTime.now(),
      coverUrl: 'https://cdn.example/cover.jpg',
      description: 'Описание из Steam',
      steamAppId: 620,
    );

    final restored = Game.fromJson(game.toJson());

    expect(restored.coverUrl, game.coverUrl);
    expect(restored.description, game.description);
    expect(restored.steamAppId, game.steamAppId);
  });

  test('загрузка настроек завершается и без изменения значений', () async {
    settings.add(const SettingsLoadRequested());
    await settings.loaded.timeout(const Duration(seconds: 1));
    expect(settings.state.installDir, paths.defaultInstallDir);
  });

  test('повреждённая запись не скрывает исправные игры', () async {
    await Directory(paths.dataDir).create(recursive: true);
    await File(paths.libraryFile).writeAsString(
      jsonEncode({
        'version': 1,
        'games': [
          Game(
            id: 'valid',
            title: 'Исправная',
            addedAt: DateTime.now(),
          ).toJson(),
          {'id': 123, 'title': 'Повреждённая'},
        ],
      }),
    );

    library.add(const LibraryLoadRequested());
    await waitFor((state) => state.loaded);

    expect(library.state.games.map((game) => game.id), ['valid']);
    expect(library.state.notice?.isError, isTrue);
    expect(
      Directory(paths.dataDir)
          .listSync()
          .where((file) => file.path.contains('.corrupt-')),
      hasLength(1),
    );
  });

  // Негодная кодировка приходила не `FormatException`, а
  // `FileSystemException`, которое чтение не ловило: библиотека так и не
  // загружалась, и окно оставалось пустым без единого слова.
  test(
    'библиотека с битой кодировкой уводится в сторону, а не вешает загрузку',
    () async {
      await Directory(paths.dataDir).create(recursive: true);
      await File(paths.libraryFile).writeAsBytes([
        ...utf8.encode('{"version": 1, "games": [{"title": "'),
        0xFF,
        0xFE,
        0xC3,
        ...utf8.encode('"}]}'),
      ]);

      library.add(const LibraryLoadRequested());
      await waitFor((state) => state.loaded);

      expect(library.state.games, isEmpty);
      expect(library.state.notice?.isError, isTrue);
      expect(
        Directory(paths.dataDir)
            .listSync()
            .where((file) => file.path.contains('.corrupt-')),
        hasLength(1),
      );
    },
  );

  // `.cast<String>()` ленив: не-строка в списке ронялась не при разборе, в
  // его `try`, а при первом чтении поля — посреди отрисовки или снимка.
  test('не-строка в списке путей бракует запись при чтении', () async {
    await Directory(paths.dataDir).create(recursive: true);
    final good = Game(id: 'valid', title: 'Исправная', addedAt: DateTime.now());
    await File(paths.libraryFile).writeAsString(
      jsonEncode({
        'version': 1,
        'games': [
          good.toJson(),
          {
            ...Game(
              id: 'bad',
              title: 'Битая',
              addedAt: DateTime.now(),
            ).toJson(),
            'ludusaviTemplates': [1, 2],
          },
        ],
      }),
    );

    library.add(const LibraryLoadRequested());
    await waitFor((state) => state.loaded);

    expect(library.state.games.map((game) => game.id), ['valid']);
    for (final game in library.state.games) {
      expect(() => game.ludusaviTemplates.toList(), returnsNormally);
    }
  });

  // `toJson` у снимка покрыт записью, а `fromJson` не исполнялся ни разу.
  // Сломайся он — при следующем запуске вся история сохранений исчезла бы
  // молча, а файлы снимков остались бы лежать сиротами.
  test('снимки переживают перезагрузку', () async {
    final savesDir = Directory(p.join(tmp.path, 'сейвы'));
    await savesDir.create(recursive: true);
    await File(p.join(savesDir.path, 'slot.sav')).writeAsString('прогресс');

    final id = addGame('Игра');
    await waitFor((s) => s.gameById(id) != null);
    library.add(
      SaveRulesAdded(id, [
        SavePathRule(
          id: 'rule-1',
          label: 'Сохранения',
          template: savesDir.path,
        ),
      ]),
    );
    final configured = await waitFor(
      (s) => s.gameById(id)!.saveProfile.isConfigured,
    );

    saves.add(SnapshotRequested(configured.gameById(id)!));
    final withSnapshot = await waitForSaves(
      (s) => s.snapshotsFor(id).isNotEmpty,
    );
    final before = withSnapshot.snapshotsFor(id).single;

    await saves.persist();
    final reopened = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
    );
    addTearDown(reopened.close);
    reopened.add(const SavesLoadRequested());
    await reopened.stream.firstWhere((s) => s.loaded);

    final after = reopened.state.snapshotsFor(id).single;
    expect(after.id, before.id);
    expect(after.gameTitle, before.gameTitle);
    expect(after.archivePath, before.archivePath);
    expect(after.fileCount, before.fileCount);
    expect(after.origin, before.origin);
    // По времени снятия массовая загрузка решает, не откатывает ли она
    // прогресс: потеряйся оно при чтении — проверка стала бы бессмысленной.
    expect(after.createdAt, before.createdAt);
  });

  test(
    'снимок без настроенных путей сообщает об ошибке, а не падает',
    () async {
      final id = addGame('Без путей');
      final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

      saves.add(SnapshotRequested(game));
      final state = await waitForSaves((s) => s.notice != null);

      expect(state.notice?.isError, isTrue);
      expect(state.notice?.message, contains('не заданы'));
      // Занятость обязана сняться даже после ошибки, иначе кнопка залипнет.
      expect(saves.state.isBusy(SavesBloc.snapshotKey(id)), isFalse);
    },
  );

  test('успешный снимок регистрируется и даёт сообщение', () async {
    final savesDir = Directory(p.join(tmp.path, 'saves'));
    await savesDir.create(recursive: true);
    await File(p.join(savesDir.path, 'slot.sav')).writeAsString('прогресс');

    final id = addGame('С путями');
    await waitFor((s) => s.gameById(id) != null);

    library.add(
      SaveRulesAdded(id, [
        SavePathRule(
          id: const Uuid().v4(),
          label: 'Сохранения',
          template: savesDir.path,
        ),
      ]),
    );
    final ready = await waitFor(
      (s) => s.gameById(id)!.saveProfile.isConfigured,
    );

    saves.add(SnapshotRequested(ready.gameById(id)!));
    final done = await waitForSaves((s) => s.snapshotsFor(id).isNotEmpty);

    expect(done.snapshotsFor(id), hasLength(1));
    expect(saves.state.notice?.isError, isFalse);
    expect(saves.state.isBusy(SavesBloc.snapshotKey(id)), isFalse);
  });

  test('выход из игры засчитывает время и приходит событием', () async {
    final id = addGame('Отыгранная');
    await waitFor((s) => s.gameById(id) != null);

    // Именно так лаунчер сообщает о завершении процесса.
    library.add(
      GameExited(gameId: id, played: const Duration(minutes: 42), exitCode: 0),
    );
    final state = await waitFor(
      (s) => s.gameById(id)!.playtime > Duration.zero,
    );

    expect(state.gameById(id)?.playtime, const Duration(minutes: 42));
    expect(state.gameById(id)?.lastPlayed, isNotNull);
  });

  test('слишком короткая сессия не засчитывается', () async {
    final id = addGame('Упавшая');
    await waitFor((s) => s.gameById(id) != null);

    library.add(
      GameExited(gameId: id, played: const Duration(seconds: 5), exitCode: 1),
    );
    await waitFor((s) => s.gameById(id)!.lastPlayed != null);

    expect(library.state.gameById(id)?.playtime, Duration.zero);
  });

  test('удаление игры уносит её снимки', () async {
    final id = addGame('Удаляемая');
    final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

    library.add(GameRemoved(game));
    await waitFor((s) => s.games.isEmpty);

    await waitForSaves((s) => s.snapshotsFor(id).isEmpty);
  });

  test('два одинаковых сообщения подряд различаются по счётчику', () async {
    final id = addGame('Без путей');
    final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

    saves.add(SnapshotRequested(game));
    final first = (await waitForSaves((s) => s.notice != null)).notice!;

    saves.add(SnapshotRequested(game));
    final second = (await waitForSaves(
      (s) => s.notice != null && s.notice!.seq > first.seq,
    )).notice!;

    expect(second.message, first.message);
    expect(
      second,
      isNot(equals(first)),
      reason: 'иначе BlocListener не покажет второе сообщение',
    );
  });

  // close() раньше запускал отложенную запись, не дожидаясь её, и
  // последнее изменение пропадало при выходе из приложения.
  test('изменение переживает закрытие без явного сохранения', () async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Не потеряться'));
    await waitFor((s) => s.gameById(id) != null);

    await library.close();

    final reopened = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    reopened.add(const LibraryLoadRequested());
    await reopened.stream
        .firstWhere((s) => s.gameById(id) != null)
        .timeout(const Duration(seconds: 10));

    expect(reopened.state.gameById(id)!.title, 'Не потеряться');
    await reopened.close();
  });

  test('настройки сохраняются и читаются обратно', () async {
    settings.add(SettingsChanged(settings.state.copyWith(maxConcurrent: 5)));
    await settings.stream.firstWhere((s) => s.maxConcurrent == 5);

    final reopened = SettingsBloc(paths);
    reopened.add(const SettingsLoadRequested());
    await reopened.stream.firstWhere((s) => s.maxConcurrent == 5);

    expect(reopened.state.maxConcurrent, 5);
    await reopened.close();
  });
  group('правка игры — намерение, а не снимок', () {
    // Правка прежде несла всю игру, захваченную в миг отправки. Три правки
    // подряд, собранные от одной и той же игры, оставляли в библиотеке
    // только последнюю: каждая затирала поля остальных своими старыми.
    test('правки, отправленные подряд, не отменяют друг друга', () async {
      final id = addGame('Игра');
      await waitFor((s) => s.gameById(id) != null);

      library
        ..add(GameExecutableSet(id, '/games/game.exe'))
        ..add(AutoSnapshotChanged(id, onLaunch: true))
        ..add(
          SaveRulesAdded(id, const [
            SavePathRule(id: 'r', label: 'Сохранения', template: '/saves'),
          ]),
        );
      final state = await waitFor(
        (s) => s.gameById(id)!.saveProfile.rules.isNotEmpty,
      );

      final game = state.gameById(id)!;
      expect(game.executablePath, '/games/game.exe');
      expect(game.saveProfile.autoSnapshotOnLaunch, isTrue);
      expect(game.saveProfile.rules.single.id, 'r');
    });

    // Правило с тем же шаблоном дважды — это один и тот же путь в двух
    // снимках разом и две метки на одну папку.
    test('уже заданный путь вторым правилом не ложится', () async {
      final id = addGame('Игра');
      await waitFor((s) => s.gameById(id) != null);
      const rule = SavePathRule(id: 'a', label: 'A', template: '/saves');

      library
        ..add(SaveRulesAdded(id, const [rule]))
        ..add(
          SaveRulesAdded(id, const [
            SavePathRule(id: 'b', label: 'B', template: '/saves'),
          ]),
        )
        ..add(SaveRuleRemoved(id, 'нет такого'));
      await waitFor((s) => s.gameById(id)!.saveProfile.rules.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(library.state.gameById(id)!.saveProfile.rules.map((r) => r.id), [
        'a',
      ]);
    });

    // Снимок перед запуском идёт секунды. Правка, пришедшая за это время,
    // стиралась: запуск записывал игру из события, захваченную до снимка.
    test('запуск не стирает правку, пришедшую во время снимка', () async {
      final launching = LibraryBloc(
        automaticMetadata: false,
        paths: paths,
        settings: settings,
        launcher: _QuietLauncher(),
      );
      addTearDown(launching.close);
      final id = const Uuid().v4();
      launching.add(GameAdded(id: id, title: 'Игра'));
      final stale = (await launching.stream.firstWhere(
        (s) => s.gameById(id) != null,
      )).gameById(id)!;
      launching.beforeLaunch = (_) async {
        launching.add(
          SaveRulesAdded(id, const [
            SavePathRule(id: 'r', label: 'Сохранения', template: '/saves'),
          ]),
        );
        await launching.stream.firstWhere(
          (s) => s.gameById(id)!.saveProfile.rules.isNotEmpty,
        );
      };

      launching.add(GameLaunchRequested(stale));
      final state = await launching.stream
          .firstWhere((s) => s.gameById(id)!.status == GameStatus.running)
          .timeout(const Duration(seconds: 5));

      expect(state.gameById(id)!.saveProfile.rules, hasLength(1));
    });

    // Обход папки идёт секунды, и выбранное за это время человеком догадка
    // заменять не вправе.
    test('указанная папка не заменяет выбранный исполняемый файл', () async {
      final dir = Directory(p.join(tmp.path, 'games', 'Готовая'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'game.exe')).writeAsString('MZ');
      final id = addGame('Готовая');
      await waitFor((s) => s.gameById(id) != null);

      library
        ..add(GameExecutableSet(id, '/выбрано/человеком.exe'))
        ..add(GameInstallDirSet(id, dir.path));
      final state = await waitFor(
        (s) => s.gameById(id)!.status == GameStatus.installed,
      );

      final game = state.gameById(id)!;
      expect(game.installDir, dir.path);
      expect(game.executablePath, '/выбрано/человеком.exe');
    });
  });
}

/// Лаунчер, который ничего не запускает: тесту нужен только путь события
/// через блок, а не процесс.
class _QuietLauncher extends GameLauncher {
  @override
  Future<void> launch(
    Game game, {
    required void Function(Game game, Duration played, int exitCode) onExit,
  }) async {}
}
