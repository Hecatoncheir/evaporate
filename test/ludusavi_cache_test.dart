import 'dart:convert';
import 'dart:io';

import 'package:evaporate/core/json_store.dart';
import 'package:evaporate/models/catalog_progress.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// База путей — десятки тысяч записей, и всё, что с ней делают на главном
/// потоке, видно глазом: анимация на фоне дёргается.
void main() {
  late Directory tmp;
  late String cacheFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_cache_');
    cacheFile = p.join(tmp.path, 'paths.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Манифест из нескольких игр в том виде, в каком его отдаёт Ludusavi.
  String manifest(int count) => [
    for (var i = 0; i < count; i++)
      'Игра $i:\n'
          '  files:\n'
          '    "<home>/saves/game$i":\n'
          '      tags: [save]\n'
          '  steam:\n'
          '    id: ${1000 + i}\n',
  ].join();

  test('кэш пишется и читается обратно', () async {
    final first = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async => manifest(5),
    );
    await first.ensureLoaded();
    expect(first.entryCount, 5);

    // Второй каталог сети не видит вовсе: если он что-то нашёл, значит
    // прочитал кэш.
    final second = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async => throw StateError('сети быть не должно'),
    );

    expect(await second.ensureLoaded(), isTrue);
    expect(second.entryCount, 5);
    expect(second.find(title: 'Игра 3', steamAppId: 1003), isNotNull);
  });

  // Кэш пишет и читает не пойми что только испорченный файл: качаем заново,
  // а прежний оставляем рядом — вдруг пригодится для разбирательства.
  test('испорченный кэш не роняет загрузку и уходит в карантин', () async {
    await File(cacheFile).writeAsString('{ это не json');
    var downloads = 0;

    final catalog = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async {
        downloads++;
        return manifest(2);
      },
    );

    expect(await catalog.ensureLoaded(), isTrue);
    expect(catalog.entryCount, 2);
    expect(downloads, 1);
    expect(
      Directory(tmp.path).listSync().any((e) => e.path.contains('.corrupt-')),
      isTrue,
    );
  });

  test('кэш на диске лежит без отступов', () async {
    final catalog = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async => manifest(3),
    );
    await catalog.ensureLoaded();

    final text = await File(cacheFile).readAsString();

    // Читает его только приложение: отступы прибавляли бы к файлу треть.
    expect(text, isNot(contains('\n  ')));
    expect(jsonDecode(text), isA<Map<String, dynamic>>());
  });

  // Кусков приходит несколько сотен, и каждый поднимал событие блока с
  // перерисовкой — сотни кадров работы там, где глазу хватает десятка в
  // секунду. Ровно от этого и дёргалась анимация на фоне.
  test('о ходе загрузки сообщается не на каждый кусок', () async {
    final reports = <CatalogProgress>[];
    final catalog = LudusaviCatalog(
      cacheFile: cacheFile,
      // Настоящая загрузка кусками идёт только по сети; здесь проверяем то,
      // что видно снаружи: отчётов заметно меньше, чем записей.
      fetch: (uri) async => manifest(400),
    )..onProgress = reports.add;

    await catalog.ensureLoaded();

    expect(catalog.entryCount, 400);
    expect(reports.length, lessThan(20));
    // О разборе сообщить обязаны: он занимает секунды, и без слова о нём
    // это выглядит зависанием.
    expect(reports.any((r) => r.phase == CatalogPhase.parsing), isTrue);
  });

  test('повторная загрузка кэш не перечитывает', () async {
    var downloads = 0;
    final catalog = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async {
        downloads++;
        return manifest(2);
      },
    );

    await catalog.ensureLoaded();
    await catalog.ensureLoaded();

    expect(downloads, 1);
  });

  test('обновление по требованию идёт мимо кэша', () async {
    var downloads = 0;
    final catalog = LudusaviCatalog(
      cacheFile: cacheFile,
      fetch: (uri) async {
        downloads++;
        return manifest(downloads);
      },
    );

    await catalog.ensureLoaded();
    await catalog.ensureLoaded(refresh: true);

    expect(downloads, 2);
    expect(catalog.entryCount, 2);
  });

  test('готовый текст пишется атомарно и читается обратно', () async {
    final store = JsonStore(p.join(tmp.path, 'text.json'));

    await store.writeText('{"a":1}');

    expect(await store.readText(), '{"a":1}');
    expect(await store.read(), containsPair('a', 1));
    // Временных файлов после записи не остаётся.
    expect(
      Directory(tmp.path).listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('пустой файл читается как отсутствующий', () async {
    final store = JsonStore(p.join(tmp.path, 'empty.json'));
    await File(p.join(tmp.path, 'empty.json')).writeAsString('   ');

    expect(await store.readText(), isNull);
  });
}
