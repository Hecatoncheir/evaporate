import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Ротация снимков: `keepSnapshots` обязан держать в узде все пути, какими
/// снимок попадает в состояние, а не только кнопку «Снять».
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_rotation_');
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
  });

  tearDown(() async {
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

  /// Игра с настроенной папкой сохранений и заданным пределом снимков.
  Future<String> gameWithSave(String title, {required int keep}) async {
    final id = const Uuid().v4();
    final dir = Directory(p.join(tmp.path, 'saves', title));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'slot.sav')).writeAsString('прогресс');

    library.add(GameAdded(id: id, title: title));
    final added = await waitFor((s) => s.gameById(id) != null);
    library.add(
      GameUpdated(
        added
            .gameById(id)!
            .copyWith(
              saveProfile: SaveProfile(
                keepSnapshots: keep,
                rules: [
                  SavePathRule(
                    id: const Uuid().v4(),
                    label: SavePathRule.defaultLabel,
                    template: dir.path,
                  ),
                ],
              ),
            ),
      ),
    );
    await waitFor((s) => s.gameById(id)!.saveProfile.isConfigured);
    return id;
  }

  Future<void> takeSnapshot(String id) async {
    final before = library.state.snapshotsFor(id).length;
    library.add(SnapshotRequested(library.state.gameById(id)!));
    await waitFor(
      (s) =>
          !s.isBusy(LibraryBloc.snapshotKey(id)) &&
          s.snapshotsFor(id).length != before,
    );
  }

  /// Что реально лежит в хранилище содержимого.
  Set<String> blobsOnDisk() {
    final dir = Directory(paths.blobsDir);
    if (!dir.existsSync()) return const {};
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toSet();
  }

  /// На что ссылаются оставшиеся снимки всех игр.
  Set<String> liveBlobs() => {
    for (final list in library.state.snapshots.values)
      for (final snapshot in list)
        for (final blob in snapshot.blobs) blob.hash,
  };

  /// Ждёт, пока хранилище сойдётся со списком живых снимков.
  ///
  /// Это и есть инвариант дедупликации: на диске лежит ровно то, на что
  /// кто-то ссылается, — не больше (иначе место течёт) и не меньше (иначе
  /// снимок нечем разложить обратно). Считать архивы больше нельзя: своих
  /// архивов у снимков нет, а содержимое у них общее.
  ///
  /// Ждём по условию: ротация сначала правит состояние, а файлы убирает
  /// следом, и на машине сборки это занимает другое время.
  Future<void> waitForStore() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!setEquals(blobsOnDisk(), liveBlobs())) {
      if (DateTime.now().isAfter(deadline)) {
        fail('в хранилище ${blobsOnDisk()}, живых ссылок ${liveBlobs()}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('лишние снимки уходят и из списка, и с диска', () async {
    final id = await gameWithSave('Ротация', keep: 2);

    for (var i = 0; i < 4; i++) {
      await takeSnapshot(id);
    }

    expect(library.state.snapshotsFor(id), hasLength(2));
    await waitForStore();
  });

  // Резервная копия перед восстановлением — такой же снимок, и раньше она
  // копилась мимо предела: ротация случалась только после кнопки «Снять».
  test('резервные копии перед восстановлением тоже ротируются', () async {
    final id = await gameWithSave('Откаты', keep: 2);
    await takeSnapshot(id);

    // Каждое восстановление кладёт рядом ещё одну резервную копию.
    // Откатываемся всякий раз к самому свежему снимку: тот, с которого
    // начинали, ротация законно унесёт, и держаться за него нельзя.
    for (var i = 0; i < 3; i++) {
      final before = library.state.snapshotsFor(id).length;
      library.add(
        SnapshotRestoreRequested(
          game: library.state.gameById(id)!,
          snapshot: library.state.snapshotsFor(id).first,
        ),
      );
      await waitFor(
        (s) =>
            !s.isBusy(LibraryBloc.snapshotKey(id)) &&
            s.snapshotsFor(id).length != before,
      );
    }

    expect(library.state.snapshotsFor(id), hasLength(2));
    await waitForStore();
  });

  test('импортированные пакеты не обходят предел', () async {
    final id = await gameWithSave('Импорт', keep: 2);
    await takeSnapshot(id);
    final exported = p.join(tmp.path, 'пакет${SaveSnapshot.fileExtension}');
    await library.saveManager.exportSnapshot(
      library.state.snapshotsFor(id).single,
      exported,
    );

    for (var i = 0; i < 3; i++) {
      final before = library.state.snapshotsFor(id).length;
      library.add(
        SnapshotImportRequested(
          path: exported,
          game: library.state.gameById(id)!,
        ),
      );
      await waitFor(
        (s) =>
            !s.isBusy(LibraryBloc.snapshotKey(id)) &&
            s.snapshotsFor(id).length != before,
      );
    }

    expect(library.state.snapshotsFor(id), hasLength(2));
    await waitForStore();
  });

  // Снимок после выхода бесполезен против игры, которая портит своё
  // сохранение при старте: к моменту выхода портить уже нечего, и автоснимок
  // закрепит испорченное.
  test('перед запуском снимок снимается, если это включено', () async {
    final id = await gameWithSave('Перед стартом', keep: 5);
    final script = File(p.join(tmp.path, 'game.sh'));
    await script.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', ['+x', script.path]);

    library.add(
      GameUpdated(
        library.state
            .gameById(id)!
            .copyWith(
              executablePath: script.path,
              saveProfile: library.state
                  .gameById(id)!
                  .saveProfile
                  .copyWith(
                    autoSnapshotOnLaunch: true,
                    autoSnapshotOnExit: false,
                  ),
            ),
      ),
    );
    await waitFor((s) => s.gameById(id)!.saveProfile.autoSnapshotOnLaunch);

    library.add(GameLaunchRequested(library.state.gameById(id)!));
    await waitFor((s) => s.snapshotsFor(id).isNotEmpty);

    final snapshot = library.state.snapshotsFor(id).single;
    expect(snapshot.origin, SnapshotOrigin.autoOnLaunch);
    expect(snapshot.fileCount, 1);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('выключенный снимок перед запуском не снимается', () async {
    final id = await gameWithSave('Без снимка', keep: 5);
    final script = File(p.join(tmp.path, 'quiet.sh'));
    await script.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', ['+x', script.path]);

    library.add(
      GameUpdated(
        library.state
            .gameById(id)!
            .copyWith(
              executablePath: script.path,
              saveProfile: library.state
                  .gameById(id)!
                  .saveProfile
                  .copyWith(autoSnapshotOnExit: false),
            ),
      ),
    );
    await waitFor((s) => s.gameById(id)!.executablePath != null);

    library.add(GameLaunchRequested(library.state.gameById(id)!));
    await waitFor((s) => !s.isBusy(LibraryBloc.launchKey(id)));

    expect(library.state.snapshotsFor(id), isEmpty);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  // Ноль означает «не ротировать»: у человека может быть свой резон
  // держать всю историю.
  test('нулевой предел ничего не удаляет', () async {
    final id = await gameWithSave('Без предела', keep: 0);

    for (var i = 0; i < 3; i++) {
      await takeSnapshot(id);
    }

    expect(library.state.snapshotsFor(id), hasLength(3));
    await waitForStore();
  });
}
