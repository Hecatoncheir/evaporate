import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SaveManager manager;

  /// Свой журнал, а не глобальный: тесты идут параллельно, и поставленный
  /// в глобал отбирает журнал у соседнего файла.
  late AppLog log;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_test_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    log = AppLog(
      path: p.join(tmp.path, 'evaporate.log'),
      previousPath: p.join(tmp.path, 'evaporate.log.1'),
    );
    manager = SaveManager(paths: paths, log: () => log);
  });

  tearDown(() async {
    await deleteTempDir(tmp);
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

  /// Портит содержимое файла снимка в хранилище: на месте и не пустое, но
  /// не разворачивается — сбой на середине выгрузки без игры с правами.
  Future<void> breakBlob(SaveSnapshot snapshot, String file) async {
    final blob = snapshot.blobs.firstWhere((b) => b.name.endsWith(file));
    await manager.store.fileFor(blob.hash).writeAsString('не gzip');
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

  /// Диалог восстановления показывает человеку, куда лягут файлы, **до**
  /// того как он нажмёт. Обещание это чего-то стоит ровно постольку,
  /// поскольку предпросмотр и раскладка идут одним сопоставлением. Раньше
  /// диалог считал сам и расходился с раскладкой в двух местах.
  group('предпросмотр целей', () {
    test('совпадает с тем, куда восстановление и правда положило', () async {
      final saves = await writeSaves('предпросмотр', {'slot.sav': 'прогресс'});
      final game = gameWith(
        id: 'g1',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'rule-1',
            label: SavePathRule.defaultLabel,
            template: saves.path,
          ),
        ],
      );
      final snapshot = await manager.createSnapshot(game);

      final preview = manager.previewTargets(game, snapshot);
      final report = await manager.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
      );

      expect(preview, isNotEmpty);
      expect(preview, report.targets);
    });

    // Своего правила под эту платформу у игры нет. Диалог подставлял сюда
    // правило из снимка и показывал путь с чужой машины — тот, куда здесь
    // не запишут никогда, — да ещё и оставлял клавишу доступной.
    test('не выдумывает цель из правила, приехавшего со снимком', () async {
      final saves = await writeSaves('чужое', {'slot.sav': 'прогресс'});
      final source = gameWith(
        id: 'источник',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'rule-1',
            label: SavePathRule.defaultLabel,
            template: saves.path,
          ),
        ],
      );
      final snapshot = await manager.createSnapshot(source);

      final bare = gameWith(id: 'g2', title: 'Игра', rules: const []);
      expect(manager.previewTargets(bare, snapshot), isEmpty);
      // И раскладка того же мнения: класть некуда.
      await expectLater(
        manager.restoreSnapshot(game: bare, snapshot: snapshot),
        throwsA(isA<SaveException>()),
      );
    });

    // Две метки «Сохранения» — и непонятно, которая из них та. Раскладка от
    // двоякости отказывается, а диалог брал первую попавшуюся.
    test('от двух правил с одной меткой отказывается, а не гадает', () async {
      final saves = await writeSaves('двоякость', {'slot.sav': 'прогресс'});
      final source = gameWith(
        id: 'источник',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'rule-1',
            label: SavePathRule.defaultLabel,
            template: saves.path,
          ),
        ],
      );
      final snapshot = await manager.createSnapshot(source);

      final twin = gameWith(
        id: 'g3',
        title: 'Игра',
        rules: [
          SavePathRule(
            id: 'первое',
            label: SavePathRule.defaultLabel,
            template: p.join(tmp.path, 'первое'),
          ),
          SavePathRule(
            id: 'второе',
            label: SavePathRule.defaultLabel,
            template: p.join(tmp.path, 'второе'),
          ),
        ],
      );

      expect(manager.previewTargets(twin, snapshot), isEmpty);
      // Раскладка того же мнения: сопоставить правило не с чем.
      await expectLater(
        manager.restoreSnapshot(game: twin, snapshot: snapshot),
        throwsA(isA<SaveException>()),
      );
      expect(Directory(p.join(tmp.path, 'первое')).existsSync(), isFalse);
      expect(Directory(p.join(tmp.path, 'второе')).existsSync(), isFalse);
    });
  });

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
          'rules': const <Object?>[],
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

  // Копия снимается до замены, а в библиотеку попадала только из отчёта об
  // успехе. Сорвалась замена — копия не заведена нигде, и её содержимое
  // уносит следующая уборка: ровно тогда, когда она и нужна.
  test(
    'резервная копия доходит до вызывающего и при сорванной замене',
    () async {
      final first = await writeSaves('backup-first', {'slot': 'old-a'});
      final second = await writeSaves('backup-second', {'slot': 'old-b'});
      final game = gameWith(
        id: 'backup-kept',
        title: 'Backup kept',
        rules: [
          SavePathRule(id: 'a', label: 'A', template: first.path),
          SavePathRule(id: 'b', label: 'B', template: second.path),
        ],
      );
      final snapshot = await manager.createSnapshot(game);
      await File(p.join(first.path, 'slot')).writeAsString('current-a');
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
      final backups = <SaveSnapshot>[];

      await expectLater(
        failing.restoreSnapshot(
          game: game,
          snapshot: snapshot,
          wipeTarget: true,
          onBackup: (backup) async => backups.add(backup),
        ),
        throwsA(isA<SaveException>()),
      );

      expect(backups, hasLength(1), reason: 'копия не дошла до библиотеки');
      expect(backups.single.origin, SnapshotOrigin.preRestore);
    },
  );

  // Откат без единого `try`: на Windows свежезаписанное держит антивирус,
  // исключение вылетало из `catch`, остальные цели не откатывались, а
  // причина сбоя терялась. Человеку нужен путь, где лежат прежние сейвы.
  test('сорвавшийся откат называет, где лежат прежние сейвы', () async {
    final first = await writeSaves('stuck-first', {'slot': 'old-a'});
    final second = await writeSaves('stuck-second', {'slot': 'old-b'});
    final game = gameWith(
      id: 'stuck',
      title: 'Stuck',
      rules: [
        SavePathRule(id: 'a', label: 'A', template: first.path),
        SavePathRule(id: 'b', label: 'B', template: second.path),
      ],
    );
    final snapshot = await manager.createSnapshot(game);
    await File(p.join(first.path, 'slot')).writeAsString('current-a');
    final failing = SaveManager(
      paths: paths,
      renameForRestore: (source, destination) async {
        // Замена второй цели срывается, а возврат первой из резервного
        // имени — тоже: файл держат.
        if (source.path.contains('.evaporate-new-') &&
            destination == second.path) {
          throw FileSystemException('Simulated rename failure', destination);
        }
        if (source.path.contains('.evaporate-old-') &&
            destination == first.path) {
          throw FileSystemException('Simulated busy file', destination);
        }
        return source.rename(destination);
      },
    );

    Object? failure;
    try {
      await failing.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
        wipeTarget: true,
      );
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isA<SaveException>());
    final stranded = tmp
        .listSync()
        .where((entity) => entity.path.contains('.evaporate-old-'))
        .toList();
    expect(stranded, hasLength(1), reason: 'прежние сейвы потерялись');
    expect('$failure', contains(stranded.single.path));
    expect(
      File(p.join(stranded.single.path, 'slot')).readAsStringSync(),
      'current-a',
    );
  });

  // Два правила пакета с одной меткой сопоставлялись с одним здешним и
  // молча сливались в одну цель: файлы второго ложились поверх первого.
  test('два правила пакета на одно здешнее не сопоставляются оба', () async {
    final a = await writeSaves('twin-a', {'slot': 'из первого'});
    final b = await writeSaves('twin-b', {'slot': 'из второго'});
    final source = gameWith(
      id: 'twin-source',
      title: 'Источник',
      rules: [
        SavePathRule(id: 'p1', label: 'Сохранения', template: a.path),
        SavePathRule(id: 'p2', label: 'Сохранения', template: b.path),
      ],
    );
    final snapshot = await manager.createSnapshot(source);
    final here = await writeSaves('twin-here', {'slot': 'здешнее'});
    final game = gameWith(
      id: 'twin-here',
      title: 'Здесь',
      rules: [
        SavePathRule(id: 'local', label: 'Сохранения', template: here.path),
      ],
    );

    expect(manager.previewTargets(game, snapshot), isEmpty);
    await expectLater(
      manager.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        backupCurrent: false,
      ),
      throwsA(isA<SaveException>()),
    );
    expect(File(p.join(here.path, 'slot')).readAsStringSync(), 'здешнее');
  });

  // Вложенность ловилась только при восстановлении: снимок выходил с
  // дублями, а разложить его не удавалось никогда.
  test('снимок с пересекающимися правилами отказывает словами', () async {
    final outer = await writeSaves('overlap', {'Saves/slot': 'прогресс'});
    final game = gameWith(
      id: 'overlap',
      title: 'Пересечение',
      rules: [
        SavePathRule(id: 'o', label: 'Всё', template: outer.path),
        SavePathRule(
          id: 'i',
          label: 'Сейвы',
          template: p.join(outer.path, 'Saves'),
        ),
      ],
    );

    await expectLater(
      manager.createSnapshot(game),
      throwsA(
        isA<SaveException>().having(
          (error) => error.message,
          'message',
          allOf(contains('Всё'), contains('Сейвы')),
        ),
      ),
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

  // Чужие пакеты ходят другим путём: импорт → хранилище → раскладка, где
  // сверяется одна длина. Проверка CRC осталась только на пути старых
  // архивов, а папка синхронизации — ровно то место, где файлы бывают
  // недоехавшими.
  test('импорт пакета с неверной CRC отказывает', () async {
    final saves = await writeSaves('crc-import', {'slot': 'current'});
    final game = gameWith(
      id: 'crc-import',
      title: 'CRC',
      rules: [SavePathRule(id: 'a', label: 'A', template: saves.path)],
    );
    final snapshot = await manager.createSnapshot(game);
    final bytes = ZipEncoder().encode(
      Archive()
        ..add(
          ArchiveFile.string(
            SaveSnapshot.manifestEntry,
            jsonEncode(snapshot.toManifest()),
          ),
        )
        ..add(ArchiveFile.noCompress('data/a/slot', 4, [1, 2, 3, 4])),
    );
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 1 &&
          bytes[i + 1] == 2 &&
          bytes[i + 2] == 3 &&
          bytes[i + 3] == 4) {
        bytes[i] = 9;
        break;
      }
    }
    final broken = p.join(tmp.path, 'broken${SaveSnapshot.fileExtension}');
    await File(broken).writeAsBytes(bytes);

    await expectLater(
      manager.importPackage(broken, game: game),
      throwsA(isA<SaveException>()),
    );
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

  // Раскладка отодвигает цель в `.evaporate-old-*` и ставит на её место
  // подготовленное. Падение между двумя переименованиями оставляло сейвы
  // только под резервным именем: игра их не видела, следующий снимок
  // выходил пустым, а убрать остаток было некому.
  test(
    'сейвы, застрявшие под резервным именем, возвращаются на место',
    () async {
      final saves = await writeSaves('прерванная', {'slot.sav': 'прогресс'});
      final stranded = '${saves.path}.evaporate-old-1234';
      await saves.rename(stranded);
      final prepared = Directory(
        p.join(
          p.dirname(saves.path),
          '.${p.basename(saves.path)}.evaporate-new-5678',
        ),
      );
      await prepared.create();
      final game = gameWith(
        id: 'прерванная',
        title: 'Прерванная',
        rules: [
          SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
        ],
      );

      final snapshot = await manager.createSnapshot(game);

      expect(snapshot.fileCount, 1);
      expect(
        File(p.join(saves.path, 'slot.sav')).readAsStringSync(),
        'прогресс',
      );
      expect(Directory(stranded).existsSync(), isFalse);
      expect(prepared.existsSync(), isFalse, reason: 'заготовка — не сейв');
    },
  );

  // Цель на месте — значит, замена дошла до конца или откатилась, а копия
  // под резервным именем может оказаться единственной прежней версией.
  // Молча её удалять нельзя.
  test('при целой цели резервная копия не трогается', () async {
    final saves = await writeSaves('целая', {'slot.sav': 'новое'});
    final old = Directory('${saves.path}.evaporate-old-1');
    await old.create();
    await File(p.join(old.path, 'slot.sav')).writeAsString('старое');
    final game = gameWith(
      id: 'целая',
      title: 'Целая',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );

    await manager.createSnapshot(game);

    expect(File(p.join(saves.path, 'slot.sav')).readAsStringSync(), 'новое');
    expect(old.existsSync(), isTrue);
  });

  // Битый пакет в папке синхронизации пропускался без следа, и человек не
  // мог узнать, почему снимок с другого устройства не виден в списке.
  test('пропущенный пакет папки синхронизации остаётся в журнале', () async {
    final folder = Directory(p.join(tmp.path, 'синхронизация'));
    await folder.create();
    final broken = File(
      p.join(folder.path, 'битый${SaveSnapshot.fileExtension}'),
    );
    await broken.writeAsString('не zip');

    final found = await manager.scanSyncFolder(folder.path);
    await log.flush();

    expect(found, isEmpty);
    expect(
      (await log.tail()).any((line) => line.contains(broken.path)),
      isTrue,
    );
  });

  // Поток к файлу открывался до разбора и при ошибке разбора не
  // закрывался: на Windows битый пакет оставался заперт до выхода из
  // приложения — ни удалить, ни заменить исправным.
  test('битый пакет после неудачного чтения не остаётся запертым', () async {
    final broken = File(p.join(tmp.path, 'битый${SaveSnapshot.fileExtension}'));
    await broken.writeAsString('это не zip, а обрывок чего-то');

    await expectLater(
      manager.inspectPackage(broken.path),
      throwsA(isA<SaveException>()),
    );

    await broken.delete();
    expect(broken.existsSync(), isFalse);
  });

  // План восстановления предел размера проверял, а импорт — нет: пакет,
  // который никогда не удалось бы развернуть, целиком переливался в
  // хранилище, занимая гигабайты.
  test('пакет больше предела не импортируется', () async {
    final saves = await writeSaves('big', {'slot.sav': 'x' * 2048});
    final game = gameWith(
      id: 'big',
      title: 'Большая',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );
    final snapshot = await manager.createSnapshot(game);
    final package = p.join(tmp.path, 'большой${SaveSnapshot.fileExtension}');
    await manager.exportSnapshot(snapshot, package);
    final strict = SaveManager(paths: paths, maxSnapshotBytes: 1024);

    await expectLater(
      strict.importPackage(package, game: game),
      throwsA(isA<SaveException>()),
    );
  });

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
    final snapshot = await manager.createSnapshot(game);
    await breakBlob(snapshot, 'slot2.sav');
    final destination = p.join(tmp.path, 'вывоз${SaveSnapshot.fileExtension}');

    await expectLater(
      manager.exportSnapshot(snapshot, destination),
      throwsA(isA<SaveException>()),
    );

    // Наружу пакет не вернулся, и половина его на диске никому не нужна:
    // отличить её от целого нечем, а место она занимает то же.
    expect(File(destination).existsSync(), isFalse);
  });

  // Автовыгрузка пишет под одно и то же имя. Выгрузка писала прямо в него:
  // пропал один блоб — и из Dropbox исчез вчерашний рабочий пакет, а
  // клиент синхронизации успел унести половину нового.
  test('сорванная выгрузка не трогает прежний пакет', () async {
    final saves = await writeSaves('keep-old', {
      'slot1.sav': 'первый',
      'slot2.sav': 'второй',
    });
    final game = gameWith(
      id: 'keep-old',
      title: 'Прежний пакет',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );
    final snapshot = await manager.createSnapshot(game);
    final sync = Directory(p.join(tmp.path, 'sync'));
    final destination = p.join(sync.path, 'игра${SaveSnapshot.fileExtension}');
    await manager.exportSnapshot(snapshot, destination);
    final yesterday = await File(destination).readAsBytes();
    await breakBlob(snapshot, 'slot2.sav');

    await expectLater(
      manager.exportSnapshot(snapshot, destination),
      throwsA(isA<SaveException>()),
    );

    expect(await File(destination).readAsBytes(), yesterday);
    // И ничего своего в чужой папке не оставили.
    expect(sync.listSync().map((e) => p.basename(e.path)), [
      p.basename(destination),
    ]);
  });

  test('удачная выгрузка заменяет прежний пакет', () async {
    final saves = await writeSaves('replace-old', {'slot.sav': 'первый'});
    final game = gameWith(
      id: 'replace-old',
      title: 'Замена',
      rules: [
        SavePathRule(id: 'rule-1', label: 'Сохранения', template: saves.path),
      ],
    );
    final destination = p.join(tmp.path, 'игра${SaveSnapshot.fileExtension}');
    await manager.exportSnapshot(
      await manager.createSnapshot(game),
      destination,
    );
    await File(p.join(saves.path, 'slot.sav')).writeAsString('второй');
    final next = await manager.createSnapshot(game);

    await manager.exportSnapshot(next, destination);

    final info = await manager.inspectPackage(destination);
    expect(info.snapshot.id, next.id);
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

    /// Сколько содержимого лежит в хранилище.
    ///
    /// Считаются файлы с именем-хешем, а не все подряд: на Windows сторонний
    /// фильтр файловой системы (антивирус) на миг кладёт рядом с удаляемым
    /// файлом свой `<ХЕШ>.tmp` и сам же его убирает. Попавшись в обход, он
    /// выглядел остатком, который уборка не вынесла, хотя наше удаление
    /// каждый раз проходило успешно.
    int blobsOnDisk() {
      final dir = Directory(paths.blobsDir);
      if (!dir.existsSync()) return 0;
      final hash = RegExp(r'^[0-9a-f]{64}$');
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => hash.hasMatch(p.basename(file.path)))
          .length;
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
      final (:moved, purged: _) = await manager.collectGarbage([second]);

      expect(blobsOnDisk(), 2);
      expect(moved, greaterThan(0));
      for (final blob in second.blobs) {
        expect(manager.store.fileFor(blob.hash).existsSync(), isTrue);
      }
    });

    // Bloc обрабатывает события параллельно: `SnapshotDeleted` от соседней
    // игры спокойно приходит посреди автоснимка после выхода. Снимка в
    // состоянии библиотеки в этот миг ещё нет, а значит, нет и живых ссылок
    // на его содержимое — и уборка уносила его целиком, не сказав ни слова.
    // Снимок оставался в библиотеке с правильным числом файлов и размером,
    // а нечитаемым оказывался в тот день, когда понадобился.
    test('уборка не трогает содержимое снимка, который ещё снимают', () async {
      final saves = await writeSaves('на лету', {
        'slot.sav': 'прогресс',
        'meta.json': '{"level":3}',
      });

      // Работу держим открытой до отмашки, а не надеемся обогнать её
      // таймером: середина снятия должна быть середина, а не как повезёт.
      final release = Completer<void>();
      final taken = Completer<SaveSnapshot>();
      final work = manager.store.guard(() async {
        taken.complete(await snapshotOf(saves, 'g1'));
        await release.future;
      });

      final snapshot = await taken.future;
      final (:moved, purged: _) = await manager.collectGarbage(const []);

      expect(moved, 0);
      for (final blob in snapshot.blobs) {
        expect(
          manager.store.fileFor(blob.hash).existsSync(),
          isTrue,
          reason: 'содержимое ${blob.name} унесла уборка',
        );
      }

      // Защита держится ровно столько, сколько идёт работа: как только она
      // закончена, бесхозное содержимое уходит по общим правилам.
      release.complete();
      await work;
      await manager.collectGarbage(const []);
      expect(blobsOnDisk(), 0);
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

    // Снимок из хранилища раскладывают прямо оттуда. Прежде из него
    // собирался временный `.evsave` — гигабайты сжимались, чтобы тут же
    // разжаться, — и восстановление стоило минут замершего окна.
    test(
      'снимок из хранилища восстанавливается без временного пакета',
      () async {
        final saves = await writeSaves('прямо', {
          'slot.sav': 'исходное',
          'вложено/meta.json': '{"level":3}',
        });
        final game = gameWith(
          id: 'g1',
          title: 'Игра',
          rules: [
            SavePathRule(
              id: 'rule-1',
              label: SavePathRule.defaultLabel,
              template: saves.path,
            ),
          ],
        );
        final snapshot = await manager.createSnapshot(game);
        await File(p.join(saves.path, 'slot.sav')).writeAsString('испорчено');

        final report = await manager.restoreSnapshot(
          game: game,
          snapshot: snapshot,
          backupCurrent: false,
        );

        expect(report.isComplete, isTrue);
        expect(report.filesWritten, 2);
        expect(
          await File(p.join(saves.path, 'slot.sav')).readAsString(),
          'исходное',
        );
        expect(
          await File(p.join(saves.path, 'вложено', 'meta.json')).readAsString(),
          '{"level":3}',
        );
        // Ни одного `.evsave` рядом со снимками: временный пакет больше не
        // собирается. Папки снимков может не быть вовсе — снимку из
        // хранилища своего файла не нужно.
        final dir = Directory(paths.snapshotDirFor('g1'));
        final leftovers = dir.existsSync()
            ? dir
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.endsWith(SaveSnapshot.fileExtension))
                  .toList()
            : const <File>[];
        expect(leftovers, isEmpty);
      },
    );

    // Содержимое могло унести уборкой или потерять на диске. Узнать об
    // этом человек должен до того, как его сейвы тронут: половина
    // разложенного снимка хуже, чем неразложенный.
    test(
      'пропавшее содержимое останавливает восстановление до записи',
      () async {
        final saves = await writeSaves('пропажа', {'slot.sav': 'исходное'});
        final game = gameWith(
          id: 'g1',
          title: 'Игра',
          rules: [
            SavePathRule(
              id: 'rule-1',
              label: SavePathRule.defaultLabel,
              template: saves.path,
            ),
          ],
        );
        final snapshot = await manager.createSnapshot(game);
        await File(p.join(saves.path, 'slot.sav')).writeAsString('нынешнее');
        await manager.store.fileFor(snapshot.blobs.single.hash).delete();

        await expectLater(
          manager.restoreSnapshot(
            game: game,
            snapshot: snapshot,
            backupCurrent: false,
          ),
          throwsA(isA<SaveException>()),
        );
        expect(
          await File(p.join(saves.path, 'slot.sav')).readAsString(),
          'нынешнее',
          reason: 'сейвы тронули, хотя раскладывать было нечего',
        );
      },
    );

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
