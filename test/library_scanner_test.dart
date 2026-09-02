import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/library_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('evaporate_scan_');
  });

  tearDown(() async {
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  /// Папка с исполняемым файлом внутри — то, что мы считаем игрой.
  Future<Directory> gameDir(String name, {String? exe}) async {
    final dir = Directory(p.join(root.path, name));
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, exe ?? (Platform.isWindows ? 'game.exe' : 'game')),
    );
    await file.writeAsString(
      'двоичное содержимое подошло бы, но и текст сойдёт',
    );
    if (!Platform.isWindows) await Process.run('chmod', ['+x', file.path]);
    return dir;
  }

  Future<Directory> plainDir(String name) async {
    final dir = Directory(p.join(root.path, name));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'readme.txt')).writeAsString('ничего важного');
    return dir;
  }

  test('папка с исполняемым файлом считается игрой', () async {
    await gameDir('Хорошая Игра');

    final found = await LibraryScanner.scan(root.path);

    expect(found, hasLength(1));
    expect(found.single.title, 'Хорошая Игра');
    expect(found.single.installDir, endsWith('Хорошая Игра'));
    expect(found.single.executablePath, isNotEmpty);
  });

  test('папка без исполняемого файла игрой не считается', () async {
    await plainDir('Просто Документы');

    expect(await LibraryScanner.scan(root.path), isEmpty);
  });

  // Иначе повторное сканирование предлагало бы добавить то же самое.
  test('уже добавленные папки пропускаются', () async {
    final first = await gameDir('Первая');
    await gameDir('Вторая');

    final found = await LibraryScanner.scan(
      root.path,
      existingDirs: {first.path},
    );

    expect(found.map((g) => g.title), ['Вторая']);
  });

  test('служебные папки не предлагаются', () async {
    await gameDir('redist');
    await gameDir('Настоящая');

    final found = await LibraryScanner.scan(root.path);

    expect(found.map((g) => g.title), ['Настоящая']);
  });

  test('скрытые папки пропускаются', () async {
    await gameDir('.кэш');

    expect(await LibraryScanner.scan(root.path), isEmpty);
  });

  test('результат отсортирован по названию', () async {
    await gameDir('Яблоко');
    await gameDir('Арбуз');
    await gameDir('Банан');

    final found = await LibraryScanner.scan(root.path);

    expect(found.map((g) => g.title), ['Арбуз', 'Банан', 'Яблоко']);
  });

  test('несуществующая папка не роняет сканирование', () async {
    final missing = p.join(root.path, 'нет-такой');

    expect(await LibraryScanner.scan(missing), isEmpty);
  });

  test('предел на число находок соблюдается', () async {
    for (var i = 0; i < 5; i++) {
      await gameDir('Игра $i');
    }

    final found = await LibraryScanner.scan(root.path, limit: 2);

    expect(found, hasLength(2));
  });

  group('занятые папки', () {
    test('собираются только у игр с указанной папкой', () {
      final now = DateTime.now();
      final games = [
        Game(
          id: '1',
          title: 'С папкой',
          addedAt: now,
          installDir: '/games/first',
        ),
        Game(id: '2', title: 'Без папки', addedAt: now),
      ];

      expect(LibraryScanner.installedDirs(games), {'/games/first'});
    });
  });
}
