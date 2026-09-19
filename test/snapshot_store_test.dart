import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('ev_store_'));
  tearDown(() => deleteTempDir(tmp));

  String root() => p.join(tmp.path, 'blobs');

  // Работа начинается и кончается, пока уборка идёт по диску: конец работы
  // снимал с её содержимого защиту, а список живых у уборки был собран до
  // неё. Свежее содержимое выглядело бесхозным и уходило, а снимок в
  // библиотеке оставался со ссылкой в пустоту.
  test('работа, прошедшая посреди уборки, своё содержимое не теряет', () async {
    final listing = StreamController<FileSystemEntity>();
    final store = SnapshotStore(root: root(), listFiles: (_) => listing.stream);
    await Directory(root()).create(recursive: true);

    final garbage = await store.putBytes('мусор', utf8.encode('старое'));
    final collecting = store.collect(const {});
    listing.add(store.fileFor(garbage.hash));
    await pumpEventQueue();

    // Посреди обхода снимок целиком снят и закончен.
    final fresh = await store.guard(
      () => store.putBytes('свежее', utf8.encode('новый прогресс')),
    );
    listing.add(store.fileFor(fresh.hash));
    await listing.close();
    await collecting;

    expect(
      store.fileFor(fresh.hash).existsSync(),
      isTrue,
      reason: 'уборка унесла содержимое, которое только что положили',
    );
  });

  test('уборка без работы выносит бесхозное, а живое оставляет', () async {
    final store = SnapshotStore(root: root());
    final kept = await store.putBytes('a', utf8.encode('нужное'));
    final dropped = await store.putBytes('b', utf8.encode('ненужное'));

    final freed = await store.collect({kept.hash});

    expect(freed, greaterThan(0));
    expect(store.fileFor(kept.hash).existsSync(), isTrue);
    expect(store.fileFor(dropped.hash).existsSync(), isFalse);
  });

  // Хеш считался по одному чтению, а на диск ложилось другое: игра успела
  // дописать сейв. Под хешем лежало чужое содержимое, и ничто этого не
  // ловило — до того дня, когда снимок восстановят.
  test('хеш посчитан по тем самым байтам, что легли на диск', () async {
    final store = SnapshotStore(root: root());
    final source = _ChangingFile(
      p.join(tmp.path, 'slot.sav'),
      reads: [utf8.encode('до записи'), utf8.encode('после записи игрой')],
    );

    final blob = await store.put('slot.sav', source);

    final stored = await store
        .fileFor(blob.hash)
        .openRead()
        .transform(gzip.decoder)
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    expect(blob.hash, sha256.convert(stored).toString());
    expect(blob.size, stored.length);
  });

  test('уже лежащее содержимое второй раз не пишется', () async {
    final store = SnapshotStore(root: root());
    final path = p.join(tmp.path, 'slot.sav');
    await File(path).writeAsString('одно и то же');

    final first = await store.put('slot.sav', File(path));
    final stamp = store.fileFor(first.hash).statSync().modified;
    final second = await store.put('slot.sav', File(path));

    expect(second.hash, first.hash);
    expect(store.fileFor(first.hash).statSync().modified, stamp);
    expect(
      Directory(root()).listSync(recursive: true).whereType<File>(),
      hasLength(1),
    );
  });
}

/// Файл, который между чтениями дописывают: каждое `openRead` отдаёт
/// следующее содержимое из [reads].
class _ChangingFile implements File {
  _ChangingFile(this.path, {required this.reads});

  @override
  final String path;
  final List<List<int>> reads;
  var _read = 0;

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    final index = _read < reads.length ? _read : reads.length - 1;
    _read++;
    return Stream.value(reads[index]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
