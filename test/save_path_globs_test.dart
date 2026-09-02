import 'dart:io';

import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/services/saves/save_path_globs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_globs_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('шаблон без маски возвращается как есть', () async {
    expect(await SavePathGlobs.expand('{GAME}/saves', gameDir: tmp.path), [
      '{GAME}/saves',
    ]);
  });

  test('маска раскрывается в то, что лежит на диске', () async {
    await Directory(p.join(tmp.path, 'profiles', 'alice', 'save'))
        .create(recursive: true);
    await Directory(p.join(tmp.path, 'profiles', 'bob', 'save'))
        .create(recursive: true);
    // Папка без нужного вложения в ответ попасть не должна.
    await Directory(p.join(tmp.path, 'profiles', 'carol')).create();

    final found = await SavePathGlobs.expand(
      '{GAME}/profiles/*/save',
      gameDir: tmp.path,
    );

    expect(found.toSet(), {
      '{GAME}/profiles/alice/save',
      '{GAME}/profiles/bob/save',
    });
  });

  test('маска частью имени тоже работает', () async {
    await Directory(p.join(tmp.path, 'SaveSlot1')).create();
    await Directory(p.join(tmp.path, 'SaveSlot2')).create();
    await Directory(p.join(tmp.path, 'Config')).create();

    final found = await SavePathGlobs.expand('{GAME}/Save*', gameDir: tmp.path);

    expect(found, hasLength(2));
    expect(found.every((t) => t.startsWith('{GAME}/SaveSlot')), isTrue);
  });

  test('ничего не совпало — пустой список, а не выдуманный путь', () async {
    expect(
      await SavePathGlobs.expand('{GAME}/profiles/*/save', gameDir: tmp.path),
      isEmpty,
    );
  });

  // Иначе в правило попал бы путь с фигурными скобками внутри: он не
  // нашёлся бы никогда, а выглядел бы как настоящий.
  test('без папки игры маска не раскрывается', () async {
    expect(await SavePathGlobs.expand('{GAME}/profiles/*/save'), isEmpty);
  });

  test('точки в именах папок не считаются частью выражения', () async {
    await Directory(p.join(tmp.path, 'save.1')).create();
    await Directory(p.join(tmp.path, 'saveX1')).create();

    final found = await SavePathGlobs.expand(
      '{GAME}/save.*',
      gameDir: tmp.path,
    );

    expect(found, ['{GAME}/save.1']);
  });

  test('раскрытое сворачивается обратно в переносимый шаблон', () async {
    final home = SavePathTemplate.expand(SavePathTemplate.home);
    final dir = Directory(p.join(home, '.evaporate_globs_test'));
    await dir.create();
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final found = await SavePathGlobs.expand('{HOME}/.evaporate_globs_te*');

    expect(found, ['{HOME}/.evaporate_globs_test']);
  });
}
