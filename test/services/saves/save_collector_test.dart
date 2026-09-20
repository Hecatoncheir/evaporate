import 'dart:io';

import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/saves/save_collector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Что войдёт в снимок и когда оно менялось в последний раз.
///
/// Обход диска со своими правилами: правило указывает и на файл, и на
/// папку, вложенность не ограничена, а системный мусор о прогрессе
/// человека не говорит ничего.
void main() {
  const collector = SaveCollector();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_collect_');
  });

  tearDown(() async {
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  const rule = SavePathRule(
    id: 'r1',
    label: 'Сохранения',
    template: '{HOME}/s',
  );

  Future<String> write(String relative, String text) async {
    final file = File(p.join(tmp.path, relative.replaceAll('/', p.separator)));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
    return file.path;
  }

  test('правило на один файл даёт одну запись под своим именем', () async {
    final file = await write('slot.sav', 'прогресс');

    final collected = await collector.collect(rule, file);

    expect(collected, hasLength(1));
    expect(collected.single.archiveName, 'data/r1/slot.sav');
    expect(collected.single.size, 'прогресс'.codeUnits.length + 8);
  });

  test('папка обходится до дна, а пути внутри идут через косую', () async {
    await write('saves/slot.sav', '1');
    await write('saves/глубже/ещё/slot2.sav', '22');

    final collected = await collector.collect(rule, p.join(tmp.path, 'saves'));

    expect(collected.map((file) => file.archiveName).toSet(), {
      'data/r1/slot.sav',
      'data/r1/глубже/ещё/slot2.sav',
    });
  });

  // Эти файлы система меняет сама, и снимок от них только толстеет.
  test('системный мусор в снимок не попадает', () async {
    await write('saves/slot.sav', '1');
    await write('saves/.DS_Store', 'мусор');
    await write('saves/Thumbs.db', 'мусор');

    final collected = await collector.collect(rule, p.join(tmp.path, 'saves'));

    expect(collected, hasLength(1));
  });

  test('пустой путь — пустой список, а не отказ', () async {
    expect(await collector.collect(rule, p.join(tmp.path, 'нет')), isEmpty);
  });

  test('время правки берут самое позднее из всей папки', () async {
    final first = File(await write('saves/slot.sav', '1'));
    final second = File(await write('saves/вложено/slot2.sav', '2'));
    await first.setLastModified(DateTime(2026, 1, 1));
    await second.setLastModified(DateTime(2026, 6, 1));

    final newest = await collector.newestChangeAt(p.join(tmp.path, 'saves'));

    expect(newest, DateTime(2026, 6, 1));
  });

  // «Сохранений нет вовсе» и «сохранения старые» — разные ответы: на
  // первом диалогу восстановления нечего показывать.
  test('пустому месту время правки не выдумывают', () async {
    expect(await collector.newestChangeAt(p.join(tmp.path, 'нет')), isNull);
  });

  test('мусор не считается правкой сохранений', () async {
    await write('saves/.DS_Store', 'мусор');

    expect(await collector.newestChangeAt(p.join(tmp.path, 'saves')), isNull);
  });
}
