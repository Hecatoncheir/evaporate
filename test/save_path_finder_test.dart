import 'dart:io';

import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/services/saves/save_path_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_saves_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Папка с сохранениями: пустые каталоги поиск намеренно пропускает.
  Future<Directory> makeSaveDir(String name, {int files = 1}) async {
    final dir = Directory(p.join(tmp.path, name));
    await dir.create(recursive: true);
    for (var i = 0; i < files; i++) {
      await File(p.join(dir.path, 'slot$i.sav')).writeAsString('прогресс');
    }
    return dir;
  }

  Future<List<SavePathSuggestion>> suggest(String title) =>
      SavePathFinder.suggest(title, searchRoots: [tmp.path]);

  test('папка с точным совпадением имени находится', () async {
    await makeSaveDir('Hollow Knight');

    final found = await suggest('Hollow Knight');

    expect(found, hasLength(1));
    expect(p.basename(found.single.path), 'Hollow Knight');
  });

  test('регистр и знаки препинания не мешают', () async {
    await makeSaveDir('hollow-knight');

    final found = await suggest('Hollow Knight');

    expect(found, isNotEmpty);
  });

  test('пустая папка не предлагается', () async {
    await makeSaveDir('Celeste', files: 0);

    expect(await suggest('Celeste'), isEmpty);
  });

  test('посторонняя папка не попадает в подсказки', () async {
    await makeSaveDir('Совершенно другое');

    expect(await suggest('Hollow Knight'), isEmpty);
  });

  test('короткое вхождение не считается за находку', () async {
    // «Ori» входит в «Original Soundtrack», но три буквы — слишком слабый
    // признак, чтобы предлагать чужую папку.
    await makeSaveDir('Original Soundtrack');

    expect(await suggest('Ori'), isEmpty);
  });

  test('но точное совпадение находится и при коротком имени', () async {
    await makeSaveDir('Ori');

    expect(await suggest('Ori'), hasLength(1));
  });

  test('совпадение по всем словам названия засчитывается', () async {
    await makeSaveDir('SuperGiant Hades Saves');

    final found = await suggest('Hades SuperGiant');

    expect(found, isNotEmpty);
  });

  test('пустое название ничего не ищет', () async {
    await makeSaveDir('Hollow Knight');

    expect(await suggest('   '), isEmpty);
  });

  test('подсказка содержит число файлов и переносимый шаблон', () async {
    await makeSaveDir('Stardew Valley', files: 3);

    final found = await suggest('Stardew Valley');

    expect(found.single.fileCount, 3);
    expect(found.single.label, 'Сохранения');
    expect(
      SavePathTemplate.expand(found.single.template),
      found.single.path,
      reason: 'шаблон обязан разворачиваться обратно в тот же путь',
    );
  });

  test('несуществующий корень не роняет поиск', () async {
    final found = await SavePathFinder.suggest(
      'Что угодно',
      searchRoots: [p.join(tmp.path, 'нет-такой-папки')],
    );

    expect(found, isEmpty);
  });

  test('точное совпадение стоит выше частичного', () async {
    await makeSaveDir('Doom');
    await makeSaveDir('Doom Eternal Launcher');

    final found = await suggest('Doom');

    expect(p.basename(found.first.path), 'Doom');
  });
}
