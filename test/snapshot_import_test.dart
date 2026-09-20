import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'support/temp_dir.dart';

/// Пакет `.evsave` приходит извне — с чужого устройства, из мессенджера, с
/// флешки. Он может оказаться битым, не тем или вовсе не пакетом, и узнать
/// об этом человек должен словами.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late SavesBloc saves;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_import_');
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
    saves = SavesBloc(paths: paths, library: library, settings: settings);
  });

  tearDown(() async {
    await saves.close();
    await library.persist();
    await library.close();
    await settings.close();
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<SavesState> waitForSaves(bool Function(SavesState) condition) {
    if (condition(saves.state)) return Future.value(saves.state);
    return saves.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 10));
  }

  /// Игра с одной папкой сохранений — есть что снимать и куда класть.
  Future<Game> gameWithSave(String title) async {
    final id = const Uuid().v4();
    final dir = Directory(p.join(tmp.path, 'saves', title));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'slot.sav')).writeAsString('прогресс');

    library.add(GameAdded(id: id, title: title));
    await library.stream
        .firstWhere((s) => s.gameById(id) != null)
        .timeout(const Duration(seconds: 10));
    library.add(
      SaveRulesAdded(id, [
        SavePathRule(
          id: const Uuid().v4(),
          label: SavePathRule.defaultLabel,
          template: dir.path,
        ),
      ]),
    );
    final state = await library.stream
        .firstWhere((s) => s.gameById(id)!.saveProfile.rules.isNotEmpty)
        .timeout(const Duration(seconds: 10));
    return state.gameById(id)!;
  }

  /// Снимает снимок и выгружает его пакетом.
  Future<String> exportedPackage(Game game) async {
    saves.add(SnapshotRequested(game));
    final state = await waitForSaves((s) => s.snapshotsFor(game.id).isNotEmpty);
    final file = p.join(tmp.path, 'пакет.evsave');
    await saves.saveManager.exportSnapshot(
      state.snapshotsFor(game.id).single,
      file,
    );
    return file;
  }

  test('разобранный пакет ждёт ответа человека, а не заводится сам', () async {
    final game = await gameWithSave('Тихая гавань');
    final package = await exportedPackage(game);
    final before = saves.state.snapshotsFor(game.id).length;

    saves.add(SnapshotImportInspectRequested(path: package, game: game));
    final state = await waitForSaves((s) => s.pendingImport != null);

    expect(state.pendingImport!.info.snapshot.gameTitle, 'Тихая гавань');
    expect(state.pendingImport!.game.id, game.id);
    expect(
      saves.state.snapshotsFor(game.id),
      hasLength(before),
      reason: 'до согласия человека ничего не заводится',
    );
  });

  // Прежде это читал виджет, и его сообщение шло мимо `Notice` и журнала —
  // то есть мимо всего, по чему потом разбираются.
  test('битый пакет приходит сообщением, а не тишиной', () async {
    final game = await gameWithSave('Тихая гавань');
    final broken = p.join(tmp.path, 'не пакет.evsave');
    await File(broken).writeAsString('это вообще не zip');

    saves.add(SnapshotImportInspectRequested(path: broken, game: game));
    final state = await waitForSaves((s) => s.notice?.isError ?? false);

    expect(state.pendingImport, isNull);
    expect(state.notice!.message, isNotEmpty);
  });

  test('отказ убирает отложенный пакет', () async {
    final game = await gameWithSave('Тихая гавань');
    final package = await exportedPackage(game);

    saves.add(SnapshotImportInspectRequested(path: package, game: game));
    await waitForSaves((s) => s.pendingImport != null);
    saves.add(const SnapshotImportDismissed());
    final state = await waitForSaves((s) => s.pendingImport == null);

    expect(state.pendingImport, isNull);
  });

  test('согласие заводит снимок и убирает отложенное', () async {
    final game = await gameWithSave('Тихая гавань');
    final package = await exportedPackage(game);
    final before = saves.state.snapshotsFor(game.id).length;

    saves.add(SnapshotImportInspectRequested(path: package, game: game));
    final pending = await waitForSaves((s) => s.pendingImport != null);
    saves.add(
      SnapshotImportRequested(
        path: pending.pendingImport!.info.path,
        game: game,
      ),
    );
    final state = await waitForSaves(
      (s) => s.snapshotsFor(game.id).length > before,
    );

    expect(state.pendingImport, isNull);
  });
}
