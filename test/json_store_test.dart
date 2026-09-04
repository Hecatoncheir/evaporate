import 'dart:convert';
import 'dart:io';

import 'package:evaporate/core/json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String path;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_store_');
    path = p.join(tmp.path, 'nested', 'library.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('запись создаёт недостающие каталоги и читается обратно', () async {
    final store = JsonStore(path);

    await store.write({'version': 1, 'games': []});

    expect(await store.read(), {'version': 1, 'games': []});
  });

  test('отсутствующий файл — это не ошибка', () async {
    expect(await JsonStore(path).read(), isNull);
  });

  test('flush waits for queued writes without creating another file', () async {
    final store = JsonStore(path);
    await store.flush();
    expect(await File(path).exists(), isFalse);
    final first = store.write({'value': 1});
    final second = store.write({'value': 2});
    await store.flush();
    expect(await store.read(), {'value': 2});
    await Future.wait([first, second]);
  });

  test('пустой файл читается как отсутствие данных', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('   ');

    expect(await JsonStore(path).read(), isNull);
  });

  test('битый файл уводится в сторону, а не роняет запуск', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('{ это не json');

    expect(await JsonStore(path).read(), isNull);

    final leftovers = await file.parent
        .list()
        .where((e) => p.basename(e.path).contains('corrupt'))
        .toList();
    expect(
      leftovers,
      hasLength(1),
      reason: 'испорченные данные сохраняются для разбора, а не удаляются',
    );
    expect(await file.exists(), isFalse);
  });

  test('json массивом верхнего уровня не считается состоянием', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('[1, 2, 3]');

    expect(await JsonStore(path).read(), isNull);
  });

  test('повторная запись заменяет содержимое целиком', () async {
    final store = JsonStore(path);

    await store.write({'a': 1, 'b': 2});
    await store.write({'a': 9});

    expect(await store.read(), {'a': 9});
  });

  test('неверная схема сохраняется отдельно и не роняет чтение', () async {
    final store = JsonStore(path);
    await store.write({'count': 'not an integer'});

    final result = await store.readAs((json) => json['count'] as int);

    expect(result, isNull);
    expect(store.recoveryPath, isNotNull);
    expect(
      await File(store.recoveryPath!).readAsString(),
      contains('not an integer'),
    );
    expect(File(path).existsSync(), isFalse);
  });

  // Регрессия: раньше обе записи брали один временный файл, и вторая
  // падала на переименовании уже переименованного.
  test('одновременные записи не мешают друг другу', () async {
    final store = JsonStore(path);

    await Future.wait([
      store.write({'n': 1}),
      store.write({'n': 2}),
      store.write({'n': 3}),
    ]);

    final result = await store.read();
    expect(result, isNotNull);
    expect(result!['n'], isIn([1, 2, 3]));
  });

  test('после записей не остаётся временных файлов', () async {
    final store = JsonStore(path);

    await Future.wait([
      store.write({'n': 1}),
      store.write({'n': 2}),
    ]);

    final leftovers = await Directory(p.dirname(path))
        .list()
        .where((e) => e.path.endsWith('.tmp'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('данные на диске — валидный json', () async {
    await JsonStore(path).write({'games': [], 'version': 1});

    final decoded = jsonDecode(await File(path).readAsString());
    expect(decoded, isA<Map<String, dynamic>>());
  });
}
