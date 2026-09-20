import 'dart:io';

import 'package:evaporate/services/metadata/cover_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Кэш картинок трогает **только своё**. Обложку, которую человек выбрал
/// сам, он мог положить куда угодно — хоть в папку с фотографиями, — и
/// удалять её приложение не вправе.
void main() {
  late Directory tmp;
  late CoverCache cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_covers_');
    cache = CoverCache(
      coversDir: p.join(tmp.path, 'covers'),
      shotsDir: p.join(tmp.path, 'shots'),
    );
  });

  tearDown(() async {
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  test('обложка ложится в кэш и возвращается путём', () async {
    final path = await cache.writeCover('игра-1', [1, 2, 3]);

    expect(path, isNotNull);
    expect(File(path!).readAsBytesSync(), [1, 2, 3]);
    expect(p.isWithin(cache.coversDir, path), isTrue);
  });

  test('чужую обложку не заменяем', () async {
    final own = p.join(tmp.path, 'моя.jpg');
    await File(own).writeAsBytes([9]);

    final path = await cache.writeCover('игра-1', [1, 2, 3], current: own);

    expect(path, isNull, reason: 'выбранное человеком остаётся как есть');
    expect(File(own).existsSync(), isTrue);
  });

  test('нечего писать — нечего и возвращать', () async {
    expect(await cache.writeCover('игра-1', null), isNull);
  });

  test('кадры ложатся по порядку показа', () async {
    final paths = await cache.writeShots('игра-1', [
      [1],
      [2],
      [3],
    ]);

    expect(paths, hasLength(3));
    expect(File(paths[0]).readAsBytesSync(), [1]);
    expect(File(paths[2]).readAsBytesSync(), [3]);
  });

  test('чужой файл удалением не задевается', () async {
    final foreign = p.join(tmp.path, 'чужая.jpg');
    await File(foreign).writeAsBytes([9]);

    await cache.deleteCover(foreign);
    await cache.deleteShots([foreign]);

    expect(File(foreign).existsSync(), isTrue);
  });

  test('своё удаляется', () async {
    final cover = await cache.writeCover('игра-1', [1]);
    final shots = await cache.writeShots('игра-1', [
      [2],
    ]);

    await cache.deleteCover(cover);
    await cache.deleteShots(shots);

    expect(File(cover!).existsSync(), isFalse);
    expect(File(shots.single).existsSync(), isFalse);
  });

  // Удаление чего-то уже удалённого случается при уборке вслед за
  // заменой: отменять из-за этого найденные метаданные не за что.
  test('пропавший файл удалением не считается ошибкой', () async {
    await cache.delete(p.join(cache.coversDir, 'нет такого.jpg'));
  });
}
