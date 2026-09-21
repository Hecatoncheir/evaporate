import 'dart:convert';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/restore_transaction.dart';
import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir.dart';

/// Снимки живут в своём файле, но до 0.33 лежали в library.json
/// вместе с играми: такие библиотеки лежат у людей на дисках.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late SavesBloc saves;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_saves_store_');
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
      saveRoots: () => const [],
    );
  });

  tearDown(() async {
    await saves.close();
    await library.close();
    await settings.close();
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  SaveSnapshot snapshotOf(String id, String title) => SaveSnapshot(
    id: id,
    gameId: 'game-1',
    gameTitle: title,
    createdAt: DateTime.now(),
    sizeBytes: 10,
    fileCount: 1,
    rules: const [],
    archivePath: '',
    deviceName: 'test',
    platform: 'test',
  );

  Future<void> writeLegacy(List<SaveSnapshot> snapshots) async {
    await Directory(paths.dataDir).create(recursive: true);
    await File(paths.libraryFile).writeAsString(
      jsonEncode({
        'version': 1,
        'games': <Object>[],
        'snapshots': {'game-1': snapshots.map((s) => s.toJson()).toList()},
      }),
    );
  }

  Future<void> load() async {
    saves.add(const SavesLoadRequested());
    await saves.stream
        .firstWhere((s) => s.loaded)
        .timeout(const Duration(seconds: 10));
  }

  test('снимки из библиотечного файла не теряются при переезде', () async {
    await writeLegacy([snapshotOf('snap-1', 'Тихая гавань')]);

    await load();

    expect(saves.state.snapshotsFor('game-1').single.id, 'snap-1');
  });

  // Переезд одноразовый: библиотечный файл после него может лишиться ключа
  // снимков — их к тому времени держит свой.
  test('переехавшие снимки читаются уже из своего файла', () async {
    await writeLegacy([snapshotOf('snap-1', 'Тихая гавань')]);
    await load();

    final reopened = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      saveRoots: () => const [],
    );
    addTearDown(reopened.close);
    // Свой файл дописывается уже после того, как состояние поднято: сначала
    // блок отдаёт снимки экранам, и только потом кладёт их на диск.
    final own = File(paths.snapshotsFile);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!own.existsSync()) {
      if (DateTime.now().isAfter(deadline)) fail('свой файл не появился');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await File(paths.libraryFile).delete();
    reopened.add(const SavesLoadRequested());
    await reopened.stream
        .firstWhere((s) => s.loaded)
        .timeout(const Duration(seconds: 10));

    expect(reopened.state.snapshotsFor('game-1').single.id, 'snap-1');
  });

  // Испорченная запись — не повод потерять всю историю сохранений:
  // файлы остальных снимков лежат на диске и без ссылки стали бы сиротами.
  test('нечитаемый снимок пропускается, а соседние читаются', () async {
    await writeLegacy([
      snapshotOf('snap-1', 'Тихая гавань'),
      snapshotOf('snap-2', 'Тихая гавань'),
    ]);
    await load();
    await saves.persist();

    await File(paths.snapshotsFile).writeAsString(
      jsonEncode({
        'version': 1,
        'snapshots': {
          'game-1': [
            {'id': 'без остальных полей'},
            snapshotOf('snap-2', 'Тихая гавань').toJson(),
          ],
        },
      }),
    );

    final reopened = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      saveRoots: () => const [],
    );
    addTearDown(reopened.close);
    reopened.add(const SavesLoadRequested());
    await reopened.stream
        .firstWhere((s) => s.loaded)
        .timeout(const Duration(seconds: 10));

    expect(reopened.state.snapshotsFor('game-1').map((s) => s.id), ['snap-2']);
  });

  // Список снимков — единственное, что говорит уборке хранилища, какое
  // содержимое живо. Прочитанный не целиком, он называет мёртвым всё, что
  // было в непрочитанном, и следующая же уборка уносила содержимое всех
  // таких снимков — молча, а карантинная копия списка оставалась
  // бесполезной: ссылаться ей стало не на что.
  group('список снимков прочитан не целиком', () {
    Future<SnapshotBlob> blobOf(String text) =>
        SnapshotStore(root: paths.blobsDir)
            .putBytes('slot.sav', utf8.encode(text));

    SaveSnapshot withBlob(String id, SnapshotBlob blob) => SaveSnapshot(
      id: id,
      gameId: 'game-1',
      gameTitle: 'Тихая гавань',
      createdAt: DateTime.now(),
      sizeBytes: blob.size,
      fileCount: 1,
      rules: const [],
      archivePath: '',
      deviceName: 'test',
      platform: 'test',
      blobs: [blob],
    );

    Future<void> writeList(Object list) async {
      await Directory(paths.dataDir).create(recursive: true);
      await File(paths.snapshotsFile).writeAsString(
        jsonEncode({
          'version': 1,
          'snapshots': {'game-1': list},
        }),
      );
    }

    /// Удаление снимка — ровно тот путь, за которым идёт уборка. Закрытие
    /// блока дожидается его обработчиков, а значит, и уборки: без этого
    /// проверка «содержимое на месте» прошла бы, не дождавшись её.
    Future<void> deleteAndWait(SaveSnapshot snapshot) async {
      saves.add(SnapshotDeleted(snapshot));
      await saves.stream.firstWhere(
        (s) =>
            s.snapshotsFor(snapshot.gameId).every((x) => x.id != snapshot.id),
      );
      await saves.close();
    }

    test('нечитаемый файл не отдаёт содержимое снимков уборке', () async {
      final orphan = await blobOf('прогресс, о котором список забыл');
      await Directory(paths.dataDir).create(recursive: true);
      await File(paths.snapshotsFile).writeAsString('{"snapshots": {обрыв');

      await load();
      expect(saves.state.notice?.isError, isTrue, reason: 'порча молчит');

      final fresh = withBlob('snap-fresh', await blobOf('свежий'));
      saves.add(SnapshotTaken(fresh));
      await saves.stream.firstWhere((s) => s.snapshotsFor('game-1').isNotEmpty);
      await deleteAndWait(fresh);

      expect(
        SnapshotStore(root: paths.blobsDir).fileFor(orphan.hash).existsSync(),
        isTrue,
        reason: 'уборка унесла содержимое снимка из испорченного списка',
      );
    });

    test('нечитаемая запись переживает перезапись списка', () async {
      final lost = await blobOf('прогресс нечитаемого снимка');
      final unreadable = {
        'id': 'snap-future',
        'blobs': [lost.toJson()],
        'createdAt': 'формат новой сборки',
      };
      final readable = withBlob('snap-2', await blobOf('читаемый'));
      await writeList([unreadable, readable.toJson()]);

      await load();
      expect(saves.state.snapshotsFor('game-1').map((s) => s.id), ['snap-2']);
      expect(saves.state.notice?.isError, isTrue, reason: 'порча молчит');

      await deleteAndWait(readable);

      final written = jsonDecode(
        File(paths.snapshotsFile).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect((written['snapshots'] as Map<String, dynamic>)['game-1'], [
        unreadable,
      ]);
      expect(
        SnapshotStore(root: paths.blobsDir).fileFor(lost.hash).existsSync(),
        isTrue,
        reason: 'уборка унесла содержимое нечитаемого снимка',
      );
    });
  });

  // Автоснимок перед запуском по умолчанию выключен, а возврат застрявших
  // сейвов жил только внутри снимка и восстановления. Игра стартовала без
  // сейвов, заводила новые — и прогресс навсегда оставался в копии.
  test(
    'застрявшие сейвы возвращаются перед запуском и без автоснимка',
    () async {
      final target = p.join(tmp.path, 'saves');
      final copy = RestoreTransaction.backupPathFor(target, DateTime(2026));
      await Directory(copy).create(recursive: true);
      await File(p.join(copy, 'slot.sav')).writeAsString('прогресс');
      final game = Game(
        id: 'g',
        title: 'Игра',
        addedAt: DateTime(2026),
        saveProfile: SaveProfile(
          rules: [SavePathRule(id: 'r', label: 'Сохранения', template: target)],
        ),
      );
      expect(game.saveProfile.autoSnapshotOnLaunch, isFalse);

      await saves.snapshotBeforeLaunch(game);

      expect(File(p.join(target, 'slot.sav')).readAsStringSync(), 'прогресс');
    },
  );

  // Копия рядом с целой целью бывает единственной прежней версией, и её
  // судьбу решает человек. Строка в журнале на каждом снимке ему этого не
  // скажет — говорим сообщением, один раз, когда игры известны.
  test('о копии рядом с живыми сейвами говорят при старте', () async {
    final target = p.join(tmp.path, 'saves');
    await Directory(target).create(recursive: true);
    final copy = RestoreTransaction.backupPathFor(target, DateTime(2026));
    await Directory(copy).create();
    final game = Game(
      id: 'g',
      title: 'Игра',
      addedAt: DateTime(2026),
      saveProfile: SaveProfile(
        rules: [SavePathRule(id: 'r', label: 'Сохранения', template: target)],
      ),
    );
    await Directory(paths.dataDir).create(recursive: true);
    await File(paths.libraryFile).writeAsString(
      jsonEncode({
        'version': 1,
        'games': [game.toJson()],
      }),
    );

    library.add(const LibraryLoadRequested());
    final noticed = await saves.stream
        .firstWhere((s) => s.notice != null)
        .timeout(const Duration(seconds: 10));

    expect(noticed.notice!.message, contains(copy));
    expect(Directory(copy).existsSync(), isTrue, reason: 'копию не трогают');
  });

  // Список от сборки новее не испорчен — он просто не наш. Ни перезаписать
  // его, ни отдать уборке содержимое его снимков нельзя: откат на прошлую
  // версию после смены схемы — сценарий, который обновление предусматривает.
  test('список снимков от сборки новее не затирается', () async {
    final blob = await SnapshotStore(root: paths.blobsDir)
        .putBytes('slot.sav', utf8.encode('прогресс из будущего'));
    await Directory(paths.dataDir).create(recursive: true);
    final written = jsonEncode({
      'version': 2,
      'snapshots': {
        'game-1': [
          {
            'id': 'future',
            'blobs': [blob.toJson()],
          },
        ],
      },
    });
    await File(paths.snapshotsFile).writeAsString(written);

    await load();
    expect(saves.state.notice?.isError, isTrue, reason: 'промолчали');
    saves.add(SnapshotTaken(snapshotOf('snap-new', 'Тихая гавань')));
    await saves.stream.firstWhere((s) => s.snapshotsFor('game-1').isNotEmpty);
    saves.add(SnapshotDeleted(snapshotOf('snap-new', 'Тихая гавань')));
    await saves.close();

    expect(File(paths.snapshotsFile).readAsStringSync(), written);
    expect(
      SnapshotStore(root: paths.blobsDir).fileFor(blob.hash).existsSync(),
      isTrue,
    );
  });
}
