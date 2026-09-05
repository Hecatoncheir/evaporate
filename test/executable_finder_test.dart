import 'dart:io';

import 'package:evaporate/services/launch/executable_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_exe_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Создаёт файл нужного размера и, если нужно, делает его исполняемым.
  Future<File> makeFile(
    String relative, {
    bool executable = false,
    int size = 1024,
  }) async {
    final file = File(p.join(tmp.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(size, 0));
    if (executable && !Platform.isWindows) {
      await Process.run('chmod', ['+x', file.path]);
    }
    return file;
  }

  String exeName(String base) => Platform.isWindows ? '$base.exe' : base;

  test('в пустой папке искать нечего', () async {
    expect(await ExecutableFinder.scan(tmp.path), isEmpty);
  });

  test('несуществующая папка не роняет поиск', () async {
    expect(await ExecutableFinder.scan(p.join(tmp.path, 'нет')), isEmpty);
  });

  test('обычный файл без прав на запуск не предлагается', () async {
    await makeFile('readme.txt');

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.where((c) => c.name == 'readme.txt'), isEmpty);
  });

  test('исполняемый файл находится', () async {
    await makeFile(exeName('game'), executable: true);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.map((c) => c.name), contains(exeName('game')));
  });

  test('деинсталлятор проигрывает самой игре', () async {
    await makeFile(exeName('unins000'), executable: true, size: 4096);
    await makeFile(exeName('game'), executable: true, size: 2048);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(
      found.first.name,
      exeName('game'),
      reason: 'unins* штрафуется, даже если файл крупнее',
    );
  });

  test('распространяемые пакеты не выигрывают у игры', () async {
    await makeFile(exeName('vcredist_x64'), executable: true, size: 8192);
    await makeFile(exeName('launcher'), executable: true, size: 1024);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.first.name, exeName('launcher'));
  });

  test('файл ближе к корню предпочтительнее вложенного', () async {
    await makeFile(exeName('start'), executable: true);
    await makeFile(p.join('tools', 'deep', exeName('start')), executable: true);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(p.dirname(found.first.path), tmp.path);
  });

  test('крупный файл выигрывает у мелкого при прочих равных', () async {
    await makeFile(exeName('small'), executable: true, size: 1024);
    await makeFile(exeName('big'), executable: true, size: 6 * 1024 * 1024);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.first.name, exeName('big'));
  });

  test('скрытые файлы пропускаются', () async {
    await makeFile('.hidden', executable: true);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.where((c) => c.name == '.hidden'), isEmpty);
  });

  test('глубина обхода ограничена', () async {
    await makeFile(
      p.join('a', 'b', 'c', 'd', 'e', 'f', exeName('too_deep')),
      executable: true,
    );

    final found = await ExecutableFinder.scan(tmp.path, maxDepth: 2);

    expect(found, isEmpty);
  });

  test('бандл .app предпочитается отдельному бинарнику', () async {
    await makeFile(
      p.join('Game.app', 'Contents', 'MacOS', 'Game'),
      executable: true,
    );
    await makeFile('helper', executable: true);

    final found = await ExecutableFinder.scan(tmp.path);

    expect(found.first.name, 'Game.app');
  }, skip: !Platform.isMacOS ? 'только для macOS' : null);

  // Самый сильный признак, и до сих пор не использованный: рядом с игрой
  // лежит десяток исполняемых файлов, и лишь один назван как она сама.
  test('файл, названный как папка, выигрывает у соседей', () async {
    for (final name in ['crashpad', 'hollow_knight', 'helper']) {
      await makeFile(p.join('Hollow Knight', exeName(name)), executable: true);
    }

    final found = await ExecutableFinder.scan(
      p.join(tmp.path, 'Hollow Knight'),
    );

    expect(p.basenameWithoutExtension(found.first.path), 'hollow_knight');
  });

  test('защиты и служебные утилиты уходят вниз списка', () async {
    for (final name in ['EasyAntiCheat', 'BattlEye', 'ffmpeg', 'Игра']) {
      await makeFile(p.join('Игра', exeName(name)), executable: true);
    }

    final found = await ExecutableFinder.scan(p.join(tmp.path, 'Игра'));

    expect(p.basenameWithoutExtension(found.first.path), 'Игра');
  });
}
