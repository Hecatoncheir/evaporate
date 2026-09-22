import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/services/saves/save_exception.dart';
import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/snapshot_store_text.dart';
import '../../support/temp_dir.dart';

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

    final garbage = await store.putText('мусор', 'старое');
    final collecting = store.collect(const {});
    listing.add(store.fileFor(garbage.hash));
    await pumpEventQueue();

    // Посреди обхода снимок целиком снят и закончен.
    final fresh = await store.guard(
      () => store.putText('свежее', 'новый прогресс'),
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
    final kept = await store.putText('a', 'нужное');
    final dropped = await store.putText('b', 'ненужное');

    final (:moved, purged: _) = await store.collect({kept.hash});

    expect(moved, greaterThan(0));
    expect(store.fileFor(kept.hash).existsSync(), isTrue);
    expect(store.fileFor(dropped.hash).existsSync(), isFalse);
  });

  // Уборка верит списку живых снимков, а список бывал неполным так, как
  // никто не предусмотрел. Вынесенное должно вернуться, стоит снимку на
  // него сослаться.
  group('вынесенное уборкой', () {
    test('возвращается, когда снимок на него сошлётся', () async {
      final store = SnapshotStore(root: root());
      final blob = await store.putText('slot.sav', 'прогресс');
      await store.collect(const {});
      expect(store.fileFor(blob.hash).existsSync(), isFalse);

      final target = p.join(tmp.path, 'назад', 'slot.sav');
      expect(await store.contains(blob.hash), isTrue);
      await store.extractTo(blob.hash, target);

      expect(File(target).readAsStringSync(), 'прогресс');
      expect(store.fileFor(blob.hash).existsSync(), isTrue);
    });

    test('то же содержимое заново не пишется, а возвращается', () async {
      final store = SnapshotStore(root: root());
      final first = await store.putText('slot.sav', 'прогресс');
      await store.collect(const {});

      final again = await store.putText('slot.sav', 'прогресс');

      expect(again.hash, first.hash);
      expect(store.fileFor(first.hash).existsSync(), isTrue);
      expect(Directory(store.trash).listSync(), isEmpty);
    });

    test('удаляется насовсем только по сроку', () async {
      var now = DateTime(2026, 9, 21);
      final store = SnapshotStore(root: root(), clock: () => now);
      final blob = await store.putText('slot.sav', 'прогресс');
      await store.collect(const {});

      now = now.add(store.trashKeep - const Duration(hours: 1));
      expect((await store.collect(const {})).purged, 0);
      expect(await store.contains(blob.hash), isTrue);
      await store.collect(const {});

      now = now.add(store.trashKeep + const Duration(hours: 1));
      final (moved: _, :purged) = await store.collect(const {});

      expect(purged, greaterThan(0));
      expect(await store.contains(blob.hash), isFalse);
    });
  });

  // После обрыва питания под верным хешем лежит пустой или обрезанный файл,
  // и каждый следующий снимок неизменившегося сейва отвечал «уже лежит».
  // Выяснялось это в день восстановления.
  group('испорченное содержимое', () {
    test('пустой файл под хешем считается отсутствующим', () async {
      final store = SnapshotStore(root: root());
      final blob = await store.putText('slot.sav', 'прогресс');
      await store.fileFor(blob.hash).writeAsBytes(const []);

      await store.putText('slot.sav', 'прогресс');

      final target = p.join(tmp.path, 'назад.sav');
      await store.extractTo(blob.hash, target);
      expect(File(target).readAsStringSync(), 'прогресс');
    });

    // Обрезанный на середине gzip по имени и длине не отличить. Раскладка
    // его ловит — и тогда он уходит, чтобы следующий снимок того же
    // содержимого его переписал, а не ответил «уже лежит».
    test('обрезанный блоб, сорвавший раскладку, переписывается', () async {
      final store = SnapshotStore(root: root());
      final text = 'прогресс ' * 200;
      final content = utf8.encode(text);
      final blob = await store.putText('slot.sav', text);
      final stored = store.fileFor(blob.hash);
      final whole = await stored.readAsBytes();
      await stored.writeAsBytes(whole.sublist(0, whole.length ~/ 2));

      final source = StoredBlobSource(
        blob,
        store: store,
        localizations: LRu.new,
      );
      await expectLater(
        source.writeTo(p.join(tmp.path, 'первый.sav')),
        throwsA(isA<SaveException>()),
      );

      await store.putText('slot.sav', text);
      await source.writeTo(p.join(tmp.path, 'второй.sav'));
      expect(File(p.join(tmp.path, 'второй.sav')).readAsBytesSync(), content);
    });
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

  // Длина — того, что отдаст следующее чтение: по ней хранилище решает,
  // читать ли на месте или в изоляте.
  @override
  Future<int> length() async =>
      reads[_read < reads.length ? _read : reads.length - 1].length;

  @override
  Future<DateTime> lastModified() async => DateTime(2026);

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    final index = _read < reads.length ? _read : reads.length - 1;
    _read++;
    return Stream.value(reads[index]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
