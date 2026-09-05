import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SaveManager manager;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_test_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    manager = SaveManager(paths: paths);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<Directory> writeSaves(String name, Map<String, String> files) async {
    final dir = Directory(p.join(tmp.path, name));
    await dir.create(recursive: true);
    for (final entry in files.entries) {
      final file = File(p.join(dir.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    return dir;
  }

  Game gameWith({
    required String id,
    required String title,
    required List<SavePathRule> rules,
  }) {
    return Game(
      id: id,
      title: title,
      addedAt: DateTime.now(),
      saveProfile: SaveProfile(rules: rules),
    );
  }

  test(
    'снимок собирает файлы и переживает откат к прежнему состоянию',
    () async {
      final saves = await writeSaves('saves', {
        'slot1.sav': 'первое прохождение',
        'meta/profile.json': '{"level":7}',
      });
      final game = gameWith(
        id: 'game-1',
        title: 'Игра',
        rules: [
          SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
        ],
      );

      final snapshot = await manager.createSnapshot(game);

      expect(snapshot.fileCount, 2);
      // Своего архива у снимка нет: содержимое лежит в общем хранилище.
      expect(snapshot.isDeduplicated, isTrue);
      expect(snapshot.archivePath, isEmpty);
      for (final blob in snapshot.blobs) {
        expect(manager.store.fileFor(blob.hash).existsSync(), isTrue);
      }

      // Играем дальше и портим сейв.
      await File(p.join(saves.path, 'slot1.sav'))
          .writeAsString('всё сломалось');
      await File(p.join(saves.path, 'meta', 'profile.json')).delete();

      final report = await manager.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
      );

      expect(report.isComplete, isTrue);
      expect(report.filesWritten, 2);
      expect(
        await File(p.join(saves.path, 'slot1.sav')).readAsString(),
        'первое прохождение',
      );
      expect(
        await File(p.join(saves.path, 'meta', 'profile.json')).readAsString(),
        '{"level":7}',
      );
    },
  );

  test('снимок с одного устройства раскладывается по путям другого', () async {
    // Устройство A: сейвы лежат по своему пути.
    final deviceA = await writeSaves('deviceA', {'slot1.sav': 'прогресс A'});
    final gameA = gameWith(
      id: 'game-a',
      title: 'Игра',
      rules: [
        SavePathRule(id: 'rule-a', label: 'Сохранения', template: deviceA.path),
      ],
    );
    final snapshot = await manager.createSnapshot(gameA);

    // Устройство B: та же игра, другой путь и другой идентификатор правила.
    final deviceB = Directory(p.join(tmp.path, 'deviceB'));
    final gameB = gameWith(
      id: 'game-b',
      title: 'Игра',
      rules: [
        SavePathRule(id: 'rule-b', label: 'Сохранения', template: deviceB.path),
      ],
    );

    final report = await manager.restoreSnapshot(
      game: gameB,
      snapshot: snapshot,
      backupCurrent: false,
    );

    expect(
      report.isComplete,
      isTrue,
      reason: 'правила должны сопоставиться по метке',
    );
    expect(
      await File(p.join(deviceB.path, 'slot1.sav')).readAsString(),
      'прогресс A',
    );
  });

  test(
    'несопоставленные правила не используют путь из внешнего пакета',
    () async {
      final saves = await writeSaves('saves2', {'a.sav': 'x'});
      final gameA = gameWith(
        id: 'game-a',
        title: 'Игра',
        rules: [
          SavePathRule(id: 'rule-a', label: 'Сохранения', template: saves.path),
          SavePathRule(
            id: 'rule-dlc',
            label: 'Дополнение',
            template: (await writeSaves('dlc', {'b.sav': 'y'})).path,
          ),
        ],
      );
      final snapshot = await manager.createSnapshot(gameA);

      final target = Directory(p.join(tmp.path, 'targetOnlyMain'));
      final gameB = gameWith(
        id: 'game-b',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'other',
            label: 'Сохранения',
            template: target.path,
            platform: 'plan9', // правило для «другой» платформы
          ),
        ],
      );

      await expectLater(
        manager.restoreSnapshot(
          game: gameB,
          snapshot: snapshot,
          backupCurrent: false,
        ),
        throwsA(isA<SaveException>()),
      );
      expect(target.existsSync(), isFalse);
      expect(await File(p.join(saves.path, 'a.sav')).readAsString(), 'x');
    },
  );

  test('правило для одного файла восстанавливает сам файл', () async {
    final saveFile = File(p.join(tmp.path, 'single', 'profile.sav'));
    await saveFile.parent.create(recursive: true);
    await saveFile.writeAsString('исходное');
    final game = gameWith(
      id: 'single-file',
      title: 'Один файл',
      rules: [
        SavePathRule(
          id: 'single-rule',
          label: 'Сохранения',
          template: saveFile.path,
        ),
      ],
    );

    final snapshot = await manager.createSnapshot(game);
    await saveFile.writeAsString('изменённое');
    await manager.restoreSnapshot(
      game: game,
      snapshot: snapshot,
      backupCurrent: false,
    );

    expect(await saveFile.readAsString(), 'исходное');
    expect(Directory(saveFile.path).existsSync(), isFalse);
  });

  /// Кладёт рядом пакет с подписью [format] и больше ничем.
  Future<String> packageWithFormat(String format) async {
    final archivePath = p.join(tmp.path, 'foreign.evsave');
    final encoder = ZipFileEncoder();
    encoder.create(archivePath);
    encoder.addArchiveFile(
      ArchiveFile.string(
        SaveSnapshot.manifestEntry,
        jsonEncode({
          'format': format,
          'id': 'чужой',
          'gameId': 'game-1',
          'gameTitle': 'Игра',
          'createdAt': DateTime.now().toIso8601String(),
          'rules': const [],
        }),
      ),
    );
    await encoder.close();
    return archivePath;
  }

  // Проверка версии — единственное, что стоит между чужим пакетом и папкой
  // сохранений. Ветку отказа никто не проходил, и сломаться она могла молча.
  test('пакет незнакомой версии не читается', () async {
    final path = await packageWithFormat('evaporate.save/2');

    await expectLater(
      manager.inspectPackage(path),
      throwsA(
        isA<SaveException>().having(
          (e) => e.message,
          'сообщение',
          contains('evaporate.save/2'),
        ),
      ),
    );
  });

  // Иначе список читаемых версий разошёлся бы с тем, чем подписывают свои:
  // сборка перестала бы читать собственные пакеты, и заметил бы это
  // пользователь, а не тест.
  test('своя версия входит в число читаемых', () async {
    expect(SaveSnapshot.readableFormats, contains(SaveSnapshot.manifestFormat));

    final path = await packageWithFormat(SaveSnapshot.manifestFormat);
    final info = await manager.inspectPackage(path);

    expect(info.snapshot.gameTitle, 'Игра');
  });

  test('пакет с выходом за пределы папки отклоняется (zip-slip)', () async {
    final saves = await writeSaves('victim', {'ok.sav': 'ok'});
    final game = gameWith(
      id: 'game-1',
      title: 'Игра',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );

    final manifest = {
      'format': SaveSnapshot.manifestFormat,
      'id': 'malicious',
      'gameId': 'game-1',
      'gameTitle': 'Игра',
      'createdAt': DateTime.now().toIso8601String(),
      'rules': [
        {'id': 'rule-1', 'label': 'Сохранения', 'template': saves.path},
      ],
    };

    final archivePath = p.join(tmp.path, 'evil.evsave');
    final encoder = ZipFileEncoder();
    encoder.create(archivePath);
    encoder.addArchiveFile(
      ArchiveFile.string(SaveSnapshot.manifestEntry, jsonEncode(manifest)),
    );
    encoder.addArchiveFile(
      ArchiveFile.string('data/rule-1/../../pwned.txt', 'вредонос'),
    );
    await encoder.close();

    final snapshot = SaveSnapshot(
      id: 'malicious',
      gameId: 'game-1',
      gameTitle: 'Игра',
      createdAt: DateTime.now(),
      deviceName: 'чужое',
      platform: 'linux',
      sizeBytes: 0,
      archivePath: archivePath,
      rules: const [],
    );

    await expectLater(
      manager.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
      ),
      throwsA(isA<SaveException>()),
    );
    expect(File(p.join(tmp.path, 'pwned.txt')).existsSync(), isFalse);
  });

  test('ошибка в конце пакета не стирает цель при wipeTarget', () async {
    final saves = await writeSaves('atomic-target', {'current.sav': 'живой'});
    final game = gameWith(
      id: 'atomic',
      title: 'Атомарная',
      rules: [
        SavePathRule(
          id: 'atomic-rule',
          label: 'Сохранения',
          template: saves.path,
        ),
      ],
    );
    final archivePath = p.join(tmp.path, 'invalid-late.evsave');
    final encoder = ZipFileEncoder();
    encoder.create(archivePath);
    encoder.addArchiveFile(
      ArchiveFile.string(
        SaveSnapshot.manifestEntry,
        jsonEncode({
          'format': SaveSnapshot.manifestFormat,
          'id': 'invalid-late',
          'gameId': game.id,
          'gameTitle': game.title,
          'createdAt': DateTime.now().toIso8601String(),
          'rules': [game.saveProfile.rules.single.toJson()],
        }),
      ),
    );
    encoder.addArchiveFile(
      ArchiveFile.string('data/atomic-rule/new.sav', 'новый'),
    );
    encoder.addArchiveFile(
      ArchiveFile.string('data/atomic-rule/../escape.sav', 'опасный'),
    );
    await encoder.close();
    final snapshot = SaveSnapshot(
      id: 'invalid-late',
      gameId: game.id,
      gameTitle: game.title,
      createdAt: DateTime.now(),
      deviceName: 'device',
      platform: 'linux',
      sizeBytes: 0,
      archivePath: archivePath,
      rules: game.saveProfile.rules,
    );

    await expectLater(
      manager.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
        wipeTarget: true,
      ),
      throwsA(isA<SaveException>()),
    );

    expect(
      await File(p.join(saves.path, 'current.sav')).readAsString(),
      'живой',
    );
    expect(File(p.join(saves.path, 'new.sav')).existsSync(), isFalse);
  });

  test('пустые пути дают внятную ошибку, а не пустой архив', () async {
    final game = gameWith(
      id: 'game-empty',
      title: 'Игра',
      rules: [
        SavePathRule(
          id: 'rule-1',
          label: 'Сохранения',
          template: p.join(tmp.path, 'ничего-нет'),
        ),
      ],
    );

    await expectLater(
      manager.createSnapshot(game),
      throwsA(isA<SaveException>()),
    );
  });

  test('сбой замены второй цели откатывает обе цели', () async {
    final first = await writeSaves('rollback-first', {'slot': 'old-a'});
    final second = await writeSaves('rollback-second', {'slot': 'old-b'});
    final game = gameWith(
      id: 'rollback',
      title: 'Rollback',
      rules: [
        SavePathRule(id: 'a', label: 'A', template: first.path),
        SavePathRule(id: 'b', label: 'B', template: second.path),
      ],
    );
    final snapshot = await manager.createSnapshot(game);
    await File(p.join(first.path, 'slot')).writeAsString('current-a');
    await File(p.join(second.path, 'slot')).writeAsString('current-b');
    final failing = SaveManager(
      paths: paths,
      renameForRestore: (source, destination) async {
        if (source.path.contains('.evaporate-new-') &&
            destination == second.path) {
          throw FileSystemException('Simulated rename failure', destination);
        }
        return source.rename(destination);
      },
    );

    await expectLater(
      failing.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
        wipeTarget: true,
      ),
      throwsA(isA<SaveException>()),
    );

    expect(await File(p.join(first.path, 'slot')).readAsString(), 'current-a');
    expect(await File(p.join(second.path, 'slot')).readAsString(), 'current-b');
    expect(
      tmp.listSync().where((entity) => entity.path.contains('.evaporate-')),
      isEmpty,
    );
  });

  test('ошибка создания бэкапа отменяет восстановление', () async {
    final saves = await writeSaves('backup-failure', {'slot': 'old'});
    final game = gameWith(
      id: 'backup',
      title: 'Backup',
      rules: [SavePathRule(id: 'a', label: 'A', template: saves.path)],
    );
    final snapshot = await manager.createSnapshot(game);
    await File(p.join(saves.path, 'slot')).writeAsString('current');

    await expectLater(
      _FailingBackupManager(paths: paths)
          .restoreSnapshot(game: game, snapshot: snapshot, wipeTarget: true),
      throwsA(isA<SaveException>()),
    );
    expect(await File(p.join(saves.path, 'slot')).readAsString(), 'current');
  });

  test('неверная CRC отклоняется до замены существующих сейвов', () async {
    final saves = await writeSaves('crc', {'slot': 'current'});
    final game = gameWith(
      id: 'crc',
      title: 'CRC',
      rules: [SavePathRule(id: 'a', label: 'A', template: saves.path)],
    );
    final snapshot = await manager.createSnapshot(game);
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          SaveSnapshot.manifestEntry,
          jsonEncode(snapshot.toManifest()),
        ),
      )
      ..add(ArchiveFile.noCompress('data/a/slot', 4, [1, 2, 3, 4]));
    final bytes = ZipEncoder().encode(archive);
    final offset = bytes.indexOf(1);
    // Ищем уникальную последовательность payload, не заголовок ZIP.
    var payload = -1;
    for (var i = offset; i + 3 < bytes.length; i++) {
      if (bytes[i] == 1 &&
          bytes[i + 1] == 2 &&
          bytes[i + 2] == 3 &&
          bytes[i + 3] == 4) {
        payload = i;
        break;
      }
    }
    expect(payload, greaterThanOrEqualTo(0));
    bytes[payload] = 9;
    // Битый пакет подкладываем как снимок со своим архивом: так лежат
    // снятые до появления хранилища, и разбирает их тот же самый код.
    final broken = p.join(tmp.path, 'broken${SaveSnapshot.fileExtension}');
    await File(broken).writeAsBytes(bytes);

    await expectLater(
      manager.restoreSnapshot(
        game: game,
        snapshot: snapshot.copyWith(archivePath: broken, blobs: const []),
        backupCurrent: false,
        wipeTarget: true,
      ),
      throwsA(isA<SaveException>()),
    );
    expect(await File(p.join(saves.path, 'slot')).readAsString(), 'current');
    expect(
      tmp.listSync().where((entity) => entity.path.contains('.evaporate-new-')),
      isEmpty,
    );
  });

  test(
    'манифест читается без распаковки и сообщает платформу-источник',
    () async {
      final saves = await writeSaves('inspect', {'s.sav': 'z'});
      final game = gameWith(
        id: 'game-1',
        title: 'Инспектируемая',
        rules: [
          SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
        ],
      );
      final snapshot = await manager.createSnapshot(game);
      // Пакет собирается по требованию: у снимка своего файла больше нет.
      final exported = p.join(tmp.path, 'п${SaveSnapshot.fileExtension}');
      await manager.exportSnapshot(snapshot, exported);

      final info = await manager.inspectPackage(exported);

      expect(info.snapshot.gameTitle, 'Инспектируемая');
      expect(info.snapshot.fileCount, 1);
      expect(info.isCompatible, isTrue);
    },
  );

  test('оборвавшаяся выгрузка не оставляет недописанный пакет', () async {
    final saves = await writeSaves('partial', {
      'slot1.sav': 'первый',
      'slot2.sav': 'второй',
    });
    final game = gameWith(
      id: 'partial',
      title: 'Оборванная',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );
    final failing = SaveManager(
      paths: paths,
      addToArchive: (encoder, file, name) async {
        if (name.endsWith('slot2.sav')) {
          throw FileSystemException('Simulated read failure', file.path);
        }
        return encoder.addFile(file, name);
      },
    );
    final snapshot = await failing.createSnapshot(game);
    final destination = p.join(tmp.path, 'вывоз${SaveSnapshot.fileExtension}');

    await expectLater(
      failing.exportSnapshot(snapshot, destination),
      throwsA(isA<FileSystemException>()),
    );

    // Наружу пакет не вернулся, и половина его на диске никому не нужна:
    // отличить её от целого нечем, а место она занимает то же.
    expect(File(destination).existsSync(), isFalse);
  });

  group('хранилище по содержимому', () {
    Future<SaveSnapshot> snapshotOf(Directory saves, String id) =>
        manager.createSnapshot(
          gameWith(
            id: id,
            title: 'Игра',
            rules: [
              SavePathRule(
                id: 'rule-1',
                label: SavePathRule.defaultLabel,
                template: saves.path,
              ),
            ],
          ),
        );

    /// Сколько файлов лежит в хранилище содержимого.
    int blobsOnDisk() {
      final dir = Directory(paths.blobsDir);
      if (!dir.existsSync()) return 0;
      return dir.listSync(recursive: true).whereType<File>().length;
    }

    // Двадцать снимков одной игры — это двадцать полных копий её сейвов,
    // хотя между соседними меняется обычно один файл.
    test('неизменившиеся файлы лежат на диске один раз', () async {
      final saves = await writeSaves('dedup', {
        'big.sav': 'то, что не меняется' * 100,
        'slot.sav': 'первый',
      });

      final first = await snapshotOf(saves, 'g1');
      expect(blobsOnDisk(), 2);

      await File(p.join(saves.path, 'slot.sav')).writeAsString('второй');
      final second = await snapshotOf(saves, 'g1');

      // Прибавился ровно один файл — изменившийся.
      expect(blobsOnDisk(), 3);
      expect(second.fileCount, 2);

      // Ссылки обоих снимков указывают на неизменившийся файл — один и
      // тот же, а не на две его копии.
      final shared = first.blobs
          .map((b) => b.hash)
          .toSet()
          .intersection(second.blobs.map((b) => b.hash).toSet());
      expect(shared, hasLength(1));
    });

    test('одинаковые сейвы разных игр делят одно содержимое', () async {
      final a = await writeSaves('игра-а', {'slot.sav': 'ровно то же самое'});
      final b = await writeSaves('игра-б', {'slot.sav': 'ровно то же самое'});

      await snapshotOf(a, 'g1');
      await snapshotOf(b, 'g2');

      expect(blobsOnDisk(), 1);
    });

    // Содержимое общее, поэтому удалять его вместе со снимком нельзя:
    // на него может ссылаться соседний.
    test('уборка не трогает содержимое, нужное живому снимку', () async {
      final saves = await writeSaves('gc', {'a.sav': 'общее', 'b.sav': 'своё'});
      final first = await snapshotOf(saves, 'g1');
      await File(p.join(saves.path, 'b.sav')).writeAsString('другое своё');
      final second = await snapshotOf(saves, 'g1');
      expect(blobsOnDisk(), 3);

      await manager.deleteSnapshot(first);
      final freed = await manager.collectGarbage([second]);

      expect(blobsOnDisk(), 2);
      expect(freed, greaterThan(0));
      for (final blob in second.blobs) {
        expect(manager.store.fileFor(blob.hash).existsSync(), isTrue);
      }
    });

    test('уборка без единого живого снимка выносит всё', () async {
      final saves = await writeSaves('gc2', {'a.sav': 'x'});
      await snapshotOf(saves, 'g1');
      expect(blobsOnDisk(), 1);

      await manager.collectGarbage(const []);

      expect(blobsOnDisk(), 0);
    });

    // Формат пакета от дедупликации не меняется ни на байт: его уносят на
    // другую машину и читают чужие сборки, которые про хранилище не знают.
    test('выгруженный пакет остаётся самодостаточным', () async {
      final saves = await writeSaves('portable', {
        'slot.sav': 'прогресс',
        'meta/p.json': '{}',
      });
      final snapshot = await snapshotOf(saves, 'g1');
      final exported = p.join(tmp.path, 'вывоз${SaveSnapshot.fileExtension}');
      await manager.exportSnapshot(snapshot, exported);

      // Хранилище выносим целиком — пакет обязан пережить это без потерь.
      await Directory(paths.blobsDir).delete(recursive: true);

      final info = await manager.inspectPackage(exported);
      expect(info.snapshot.fileCount, 2);
      expect(info.isCompatible, isTrue);
    });

    // Снимки, снятые до появления хранилища, лежат своими архивами и
    // обязаны продолжать работать: их не переписывают, они уходят сами.
    test('снимок со своим архивом восстанавливается по-прежнему', () async {
      final saves = await writeSaves('старый', {'slot.sav': 'исходное'});
      final game = gameWith(
        id: 'старый',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'rule-1',
            label: SavePathRule.defaultLabel,
            template: saves.path,
          ),
        ],
      );
      final fresh = await manager.createSnapshot(game);
      final archive = p.join(tmp.path, 'старый${SaveSnapshot.fileExtension}');
      await manager.exportSnapshot(fresh, archive);
      final legacy = fresh.copyWith(archivePath: archive, blobs: const []);

      await Directory(paths.blobsDir).delete(recursive: true);
      await File(p.join(saves.path, 'slot.sav')).writeAsString('испорчено');

      final report = await manager.restoreSnapshot(
        game: game,
        snapshot: legacy,
        backupCurrent: false,
      );

      expect(report.isComplete, isTrue);
      expect(
        await File(p.join(saves.path, 'slot.sav')).readAsString(),
        'исходное',
      );
    });
  });
}

class _FailingBackupManager extends SaveManager {
  _FailingBackupManager({required super.paths});
  @override
  Future<SaveSnapshot> createSnapshot(
    Game game, {
    SnapshotOrigin origin = SnapshotOrigin.manual,
    String? note,
  }) async {
    throw SaveException('Simulated backup failure');
  }
}
