import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:evaporate/services/saves/save_path_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late Directory watched;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late SavesBloc saves;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_hints_');
    watched = await Directory(p.join(tmp.path, 'watched')).create();
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
      savePaths: LudusaviCatalog(
        cacheFile: p.join(tmp.path, 'paths.json'),
        fetch: (uri) async => 'Игра:\n  files:\n',
      ),
    );
    saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      saveRoots: () => [
        SaveRoot(path: watched.path, insideKnownGamesFolder: false),
      ],
    );
  });

  tearDown(() async {
    await saves.close();
    await library.persist();
    await library.close();
    await settings.close();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<LibraryState> waitFor(bool Function(LibraryState) condition) {
    if (condition(library.state)) return Future.value(library.state);
    return library.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 10));
  }

  Future<SavesState> waitForSaves(bool Function(SavesState) condition) {
    if (condition(saves.state)) return Future.value(saves.state);
    return saves.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 10));
  }

  Future<Game> addGame(String title, {String? installDir}) async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: title, installDir: installDir));
    final state = await waitFor((s) => s.gameById(id) != null);
    return state.gameById(id)!;
  }

  /// Игра «поработала» и что-то записала.
  Future<void> play(
    Game game, {
    Duration played = const Duration(minutes: 5),
  }) async {
    library.add(GameExited(gameId: game.id, played: played, exitCode: 0));
  }

  Future<void> wrote(String folder, {String file = 'slot1.sav'}) async {
    final dir = await Directory(p.join(watched.path, folder)).create();
    await File(p.join(dir.path, file)).writeAsString('прогресс');
  }

  test('после игры изменившиеся папки становятся подсказками', () async {
    final game = await addGame('Hollow Knight');
    await wrote('Hollow Knight');

    await play(game);
    final state = await waitForSaves((s) => s.hintsFor(game.id).isNotEmpty);

    expect(state.hintsFor(game.id), hasLength(1));
    expect(state.notice!.message, contains('Hollow Knight'));
  });

  test('принятая подсказка становится правилом', () async {
    final game = await addGame('Hollow Knight');
    await wrote('Hollow Knight');

    await play(game);
    final hints = await waitForSaves((s) => s.hintsFor(game.id).isNotEmpty);

    saves.add(
      SaveHintsAccepted(
        game: library.state.gameById(game.id)!,
        suggestions: hints.hintsFor(game.id),
      ),
    );
    final state = await waitFor(
      (s) => s.gameById(game.id)!.saveProfile.rules.isNotEmpty,
    );

    final rule = state.gameById(game.id)!.saveProfile.rules.single;
    expect(rule.resolve(), p.join(watched.path, 'Hollow Knight'));
    // Подсказка израсходована: показывать её второй раз незачем.
    await waitForSaves((s) => s.hintsFor(game.id).isEmpty);
  });

  test('отказ убирает подсказки, ничего не добавляя', () async {
    final game = await addGame('Hollow Knight');
    await wrote('Hollow Knight');

    await play(game);
    await waitForSaves((s) => s.hintsFor(game.id).isNotEmpty);

    saves.add(SaveHintsDismissed(game.id));
    await waitForSaves((s) => s.hintsFor(game.id).isEmpty);

    expect(library.state.gameById(game.id)!.saveProfile.rules, isEmpty);
  });

  // Игра, закрытая через пять секунд, — это неудачный запуск. Обходить
  // ради него папки незачем.
  test('слишком короткий запуск ничего не ищет', () async {
    final game = await addGame('Hollow Knight');
    await wrote('Hollow Knight');

    await play(game, played: const Duration(seconds: 5));
    // Дожидаемся, пока выход отработает: подсказок появиться не должно.
    await waitFor((s) => s.gameById(game.id)!.lastPlayed != null);

    expect(saves.state.hintsFor(game.id), isEmpty);
  });

  // Подсказывать то, что уже задано, — верный способ приучить не читать
  // подсказки вовсе.
  test('уже заданный путь второй раз не предлагается', () async {
    final game = await addGame('Hollow Knight');
    await wrote('Hollow Knight');

    await play(game);
    final hints = await waitForSaves((s) => s.hintsFor(game.id).isNotEmpty);
    saves.add(
      SaveHintsAccepted(
        game: library.state.gameById(game.id)!,
        suggestions: hints.hintsFor(game.id),
      ),
    );
    final state = await waitFor(
      (s) => s.gameById(game.id)!.saveProfile.rules.isNotEmpty,
    );

    await play(state.gameById(game.id)!);
    await waitFor((s) => s.gameById(game.id)!.lastPlayed != null);
    // Даём обходу отработать: подсказка не должна вернуться.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(saves.state.hintsFor(game.id), isEmpty);
  });
}
