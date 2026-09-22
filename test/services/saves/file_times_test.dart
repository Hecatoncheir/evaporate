import 'dart:io';

import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Разложенный снимком файл сохраняет время изменения, какое было у него
/// на снявшем устройстве.
///
/// Прежде всё разложенное датировалось «сейчас»: после любого
/// восстановления защита «здесь новее» при переносе считала здешние сейвы
/// свежее любого пакета, а игры, выбирающие «Продолжить» по времени файла,
/// путали слоты.
void main() {
  late Directory tmp;
  late SaveManager manager;

  // Круглое время в прошлом: у файловых систем разная точность, а «сейчас»
  // не отличить от того, что поставила раскладка.
  final written = DateTime(2026, 3, 14, 9, 26, 52);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_times_');
    manager = SaveManager(
      paths: AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      ),
    );
  });

  tearDown(() => deleteTempDir(tmp));

  Game gameAt(String dir, {String id = 'g1'}) => Game(
    id: id,
    title: 'Игра',
    addedAt: DateTime.now(),
    saveProfile: SaveProfile(
      rules: [SavePathRule(id: 'r-$id', label: 'Сохранения', template: dir)],
    ),
  );

  Future<String> savesWithOldSlot() async {
    final dir = p.join(tmp.path, 'saves');
    final slot = File(p.join(dir, 'slot1.sav'));
    await slot.create(recursive: true);
    await slot.writeAsString('прогресс');
    await slot.setLastModified(written);
    return dir;
  }

  Future<DateTime> modifiedOf(String dir) =>
      File(p.join(dir, 'slot1.sav')).lastModified();

  test('снимок помнит время изменения файла', () async {
    final snapshot = await manager.createSnapshot(
      gameAt(await savesWithOldSlot()),
    );

    expect(snapshot.blobs.single.modified, written);
  });

  test('восстановленный файл получает своё время, а не «сейчас»', () async {
    final source = await savesWithOldSlot();
    final snapshot = await manager.createSnapshot(gameAt(source));
    final target = p.join(tmp.path, 'restored');

    await manager.restoreSnapshot(
      game: gameAt(target, id: 'g2'),
      snapshot: snapshot,
      backupCurrent: false,
    );

    expect(await modifiedOf(target), written);
  });

  // Время уезжает в манифест пакета, а не в запись zip: там оно местное и
  // без пояса, и другое устройство сдвинуло бы его на разницу поясов.
  test('время доезжает через пакет до другого устройства', () async {
    final snapshot = await manager.createSnapshot(
      gameAt(await savesWithOldSlot()),
    );
    final package = p.join(tmp.path, 'export.evsave');
    await manager.exportSnapshot(snapshot, package);

    final target = p.join(tmp.path, 'elsewhere');
    final game = gameAt(target, id: 'g2');
    final imported = await manager.importPackage(package, game: game);
    await manager.restoreSnapshot(
      game: game,
      snapshot: imported,
      backupCurrent: false,
    );

    expect(await modifiedOf(target), written);
  });

  test('манифест несёт время по имени записи, миллисекундами эпохи', () async {
    final snapshot = await manager.createSnapshot(
      gameAt(await savesWithOldSlot()),
    );
    final manifest = snapshot.toManifest();

    expect(SaveSnapshot.modifiedOf(manifest), {
      snapshot.blobs.single.name: written,
    });
    expect(
      (manifest[SaveSnapshot.manifestModifiedKey] as Map).values.single,
      written.millisecondsSinceEpoch,
    );
  });

  test('чужие и испорченные записи времени пропускаются', () {
    expect(SaveSnapshot.modifiedOf(null), isEmpty);
    expect(SaveSnapshot.modifiedOf({'modified': 'вчера'}), isEmpty);
    expect(
      SaveSnapshot.modifiedOf({
        'modified': {'data/r/a.sav': 'нет', 'data/r/b.sav': 1000},
      }),
      {'data/r/b.sav': DateTime.fromMillisecondsSinceEpoch(1000)},
    );
  });
}
