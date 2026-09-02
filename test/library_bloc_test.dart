import 'dart:convert';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_bloc_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      paths: paths,
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
      final reopened = LibraryBloc(paths: paths, settings: settings);
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

  test(
    'снимок без настроенных путей сообщает об ошибке, а не падает',
    () async {
      final id = addGame('Без путей');
      final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

      library.add(SnapshotRequested(game));
      final state = await waitFor((s) => s.notice != null);

      expect(state.notice?.isError, isTrue);
      expect(state.notice?.message, contains('не заданы'));
      // Занятость обязана сняться даже после ошибки, иначе кнопка залипнет.
      expect(library.state.isBusy(LibraryBloc.snapshotKey(id)), isFalse);
    },
  );

  test('успешный снимок регистрируется и даёт сообщение', () async {
    final savesDir = Directory(p.join(tmp.path, 'saves'));
    await savesDir.create(recursive: true);
    await File(p.join(savesDir.path, 'slot.sav')).writeAsString('прогресс');

    final id = addGame('С путями');
    final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

    library.add(
      GameUpdated(
        game.copyWith(
          saveProfile: SaveProfile(
            rules: [
              SavePathRule(
                id: const Uuid().v4(),
                label: 'Сохранения',
                template: savesDir.path,
              ),
            ],
          ),
        ),
      ),
    );
    final ready = await waitFor(
      (s) => s.gameById(id)!.saveProfile.isConfigured,
    );

    library.add(SnapshotRequested(ready.gameById(id)!));
    final done = await waitFor((s) => s.snapshotsFor(id).isNotEmpty);

    expect(done.snapshotsFor(id), hasLength(1));
    expect(library.state.notice?.isError, isFalse);
    expect(library.state.isBusy(LibraryBloc.snapshotKey(id)), isFalse);
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

    expect(library.state.snapshotsFor(id), isEmpty);
  });

  test('два одинаковых сообщения подряд различаются по счётчику', () async {
    final id = addGame('Без путей');
    final game = (await waitFor((s) => s.gameById(id) != null)).gameById(id)!;

    library.add(SnapshotRequested(game));
    final first = (await waitFor((s) => s.notice != null)).notice!;

    library.add(SnapshotRequested(game));
    final second = (await waitFor(
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

    final reopened = LibraryBloc(paths: paths, settings: settings);
    reopened.add(const LibraryLoadRequested());
    await reopened.stream
        .firstWhere((s) => s.gameById(id) != null)
        .timeout(const Duration(seconds: 10));

    expect(reopened.state.gameById(id)!.title, 'Не потеряться');
    await reopened.close();
  });

  test('настройки сохраняются и читаются обратно', () async {
    settings.add(SettingsChanged(settings.state.copyWith(maxConcurrent: 7)));
    await settings.stream.firstWhere((s) => s.maxConcurrent == 7);

    final reopened = SettingsBloc(paths);
    reopened.add(const SettingsLoadRequested());
    await reopened.stream.firstWhere((s) => s.maxConcurrent == 7);

    expect(reopened.state.maxConcurrent, 7);
    await reopened.close();
  });
}
