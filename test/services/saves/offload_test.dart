import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/offload.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Работа с байтами снимков уходит с главного изолята.
///
/// Прежде хеш, сжатие и zip шли на том же изоляте, что рисует окно, и
/// снимок в гигабайт замораживал его на минуты. По результату это не
/// отличить — байты те же, — поэтому проверяется, куда работу отдали.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late int offloaded;
  late SaveManager manager;

  Future<R> recording<R>(FutureOr<R> Function() job) {
    offloaded++;
    return runInIsolate(job);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_offload_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    offloaded = 0;
    manager = SaveManager(paths: paths, offload: recording);
  });

  tearDown(() async {
    await deleteTempDir(tmp);
  });

  /// Игра с одним файлом сохранения заданного размера. Байты случайные:
  /// повторяющиеся сжались бы в ничто и не проверили бы ни сжатия, ни
  /// длины.
  Future<Game> gameWithSave(int size, {String id = 'g'}) async {
    final dir = Directory(p.join(tmp.path, 'saves-$id'));
    await dir.create(recursive: true);
    final random = Random(size);
    await File(p.join(dir.path, 'slot.sav'))
        .writeAsBytes(List.generate(size, (_) => random.nextInt(256)));
    return Game(
      id: id,
      title: 'Игра',
      addedAt: DateTime(2026),
      saveProfile: SaveProfile(
        rules: [SavePathRule(id: 'r', label: 'Сохранения', template: dir.path)],
      ),
    );
  }

  test('крупный файл хешируется и сжимается в изоляте', () async {
    final snapshot = await manager.createSnapshot(
      await gameWithSave(offloadFromBytes + 1),
    );

    // Хеш и сжатие — два захода: уже лежащее второй раз не сжимается.
    expect(offloaded, 2);
    expect(snapshot.blobs.single.size, offloadFromBytes + 1);
    expect(await manager.store.contains(snapshot.blobs.single.hash), isTrue);
  });

  test('мелкий файл изолята не стоит', () async {
    await manager.createSnapshot(await gameWithSave(4096));

    expect(offloaded, 0);
  });

  test('выгрузка и загрузка пакета идут в изоляте и сходятся', () async {
    final game = await gameWithSave(8192);
    final snapshot = await manager.createSnapshot(game);
    final package = p.join(tmp.path, 'игра${SaveSnapshot.fileExtension}');

    await manager.exportSnapshot(snapshot, package);
    expect(offloaded, 1);

    final imported = await manager.importPackage(package, game: game);
    expect(offloaded, 2);
    expect(imported.blobs.single.hash, snapshot.blobs.single.hash);
    expect(imported.blobs.single.name, snapshot.blobs.single.name);
    // Временные папки за собой убраны.
    expect(
      Directory(p.join(paths.dataDir, 'export-staging')).listSync(),
      isEmpty,
    );
    expect(
      Directory(paths.snapshotDirFor(game.id))
          .listSync()
          .where((e) => p.basename(e.path).startsWith('.import-')),
      isEmpty,
    );
  });

  // Обрезанный gzip разжимается без ошибки, только короче: в пакет,
  // который уносят на другую машину, лёг бы обрывок под видом сейва.
  test('обрезанное содержимое не уезжает в пакет обрывком', () async {
    final snapshot = await manager.createSnapshot(await gameWithSave(8192));
    final blob = manager.store.fileFor(snapshot.blobs.single.hash);
    final whole = await blob.readAsBytes();
    await blob.writeAsBytes(whole.sublist(0, whole.length ~/ 2));
    final package = p.join(tmp.path, 'игра${SaveSnapshot.fileExtension}');

    await expectLater(
      manager.exportSnapshot(snapshot, package),
      throwsA(isA<SaveException>()),
    );
    expect(File(package).existsSync(), isFalse);
    // И из хранилища ушло: следующий снимок того же сейва его перепишет.
    expect(blob.existsSync(), isFalse);
  });

  // Снимки, снятые до хранилища, лежат своими архивами и раскладываются
  // прямо из них — крупная запись разжимается там же, где и остальное.
  test('снимок со своим архивом разжимает крупное в изоляте', () async {
    final game = await gameWithSave(offloadFromBytes + 10);
    final save = File(p.join(tmp.path, 'saves-g', 'slot.sav'));
    final original = await save.readAsBytes();
    final fresh = await manager.createSnapshot(game);
    final archive = p.join(tmp.path, 'старый${SaveSnapshot.fileExtension}');
    await manager.exportSnapshot(fresh, archive);
    final legacy = fresh.copyWith(archivePath: archive, blobs: const []);
    await save.writeAsString('испорчено');
    offloaded = 0;

    await manager.restoreSnapshot(
      game: game,
      snapshot: legacy,
      backupCurrent: false,
    );

    expect(offloaded, 1);
    expect(await save.readAsBytes(), original);
  });

  test('хранилище само по себе отдаёт крупное изоляту', () async {
    final store = SnapshotStore(
      root: p.join(tmp.path, 'blobs'),
      offload: recording,
    );
    final big = File(p.join(tmp.path, 'big'));
    await big.writeAsBytes(List.filled(offloadFromBytes, 7));
    final blob = await store.put('big', big);
    final out = p.join(tmp.path, 'out');

    await store.extractTo(blob.hash, out, size: blob.size);

    expect(offloaded, 3);
    expect(await File(out).readAsBytes(), await big.readAsBytes());
  });
}
