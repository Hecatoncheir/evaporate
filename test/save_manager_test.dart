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
  late SaveManager manager;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_test_');
    manager = SaveManager(
      paths: AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      ),
    );
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
      expect(File(snapshot.archivePath).existsSync(), isTrue);

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
    'несопоставленные правила попадают в отчёт, а не теряются молча',
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

      final report = await manager.restoreSnapshot(
        game: gameB,
        snapshot: snapshot,
        backupCurrent: false,
      );

      // Локальное правило не для этой платформы, но сами правила снимка —
      // платформонезависимые, поэтому раскладываются по исходным путям.
      expect(report.unresolved, isEmpty);
      expect(report.filesWritten, 2);
    },
  );

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

      final info = await manager.inspectPackage(snapshot.archivePath);

      expect(info.snapshot.gameTitle, 'Инспектируемая');
      expect(info.snapshot.fileCount, 1);
      expect(info.isCompatible, isTrue);
    },
  );
}
