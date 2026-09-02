import 'dart:io';

import 'package:evaporate/services/saves/save_activity_watch.dart';
import 'package:evaporate/services/saves/save_path_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late DateTime launchedAt;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_watch_');
    // Момент «запуска» отодвинут в прошлое: файлы, созданные тестом, должны
    // считаться появившимися после него.
    launchedAt = DateTime.now().subtract(const Duration(minutes: 5));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Папка с файлом внутри — иначе смотреть не на что.
  Future<Directory> folder(String name, {String file = 'data.sav'}) async {
    final dir = await Directory(p.join(tmp.path, name)).create(recursive: true);
    await File(p.join(dir.path, file)).writeAsString('x');
    return dir;
  }

  /// Игра лежит в своей папке, а корень поиска — временная папка теста.
  Future<List<SavePathSuggestion>> look({
    required String title,
    String? gameDir,
    DateTime? since,
  }) => SaveActivityWatch.changedSince(
    since ?? launchedAt,
    gameTitle: title,
    gameDir: gameDir,
    roots: [SaveRoot(path: tmp.path, insideKnownGamesFolder: false)],
  );

  test('папка, изменившаяся при работе игры, попадает в подсказки', () async {
    await folder('Hollow Knight');

    final found = await look(title: 'Hollow Knight');

    expect(found, hasLength(1));
    expect(p.basename(found.single.path), 'Hollow Knight');
    expect(found.single.fileCount, 1);
  });

  // Иначе подсказка была бы про прошлый запуск, а то и про соседнюю игру.
  test('старые файлы не считаются следом работы', () async {
    final dir = await folder('Hollow Knight');
    final old = DateTime.now().subtract(const Duration(days: 2));
    await File(p.join(dir.path, 'data.sav')).setLastModified(old);

    expect(await look(title: 'Hollow Knight'), isEmpty);
  });

  // Пока игра работает, меняются логи, кэш шейдеров и телеметрия. Без
  // отсева список подсказок стал бы мусорным, и его перестали бы читать.
  test('кэш и логи в подсказки не попадают', () async {
    await folder('Cache');
    await folder('logs');
    await folder('CrashDumps');
    await folder('Hollow Knight');

    final found = await look(title: 'Hollow Knight');

    expect(found.map((f) => p.basename(f.path)), ['Hollow Knight']);
  });

  test('чужая папка без совпадения имени не предлагается', () async {
    await folder('Spotify');

    expect(await look(title: 'Hollow Knight'), isEmpty);
  });

  // Игры, поставленные этим лончером, чаще всего пишут сейвы прямо к себе:
  // такая находка заслуживает больше доверия, чем совпадение по имени.
  test('папка внутри игры весит больше прочего', () async {
    final gameDir = await Directory(p.join(tmp.path, 'game')).create();
    await Directory(p.join(gameDir.path, 'SaveData')).create();
    await File(p.join(gameDir.path, 'SaveData', 'slot1.sav'))
        .writeAsString('x');
    await folder('Hollow Knight Launcher');

    final found = await SaveActivityWatch.changedSince(
      launchedAt,
      gameTitle: 'Hollow Knight',
      gameDir: gameDir.path,
      roots: const [],
    );

    expect(found, isNotEmpty);
    expect(p.basename(found.first.path), 'SaveData');
    // Путь внутри игры сворачивается в переносимый шаблон.
    expect(found.first.template, '{GAME}/SaveData');
  });

  test('скрытые папки пропускаются', () async {
    await folder('.hollow knight');

    expect(await look(title: 'Hollow Knight'), isEmpty);
  });

  test('подсказок не больше восьми', () async {
    for (var i = 0; i < 12; i++) {
      await folder('Hollow Knight $i');
    }

    expect(await look(title: 'Hollow Knight'), hasLength(8));
  });
}
