import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart' as bencode;
import 'package:crypto/crypto.dart';
import 'package:evaporate/services/download/dtorrent_engine.dart';
import 'package:evaporate/services/download/torrent_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// Формат `.torrent`: infohash считается по байтам info-словаря, и любая
/// вольность с ними делает раздачу другой раздачей.
void main() {
  /// Хеши кусков — двоичный мусор, и байты `d` и `e` в нём неизбежны.
  /// Раздача без них — единственная, на которой наивный поиск границ
  /// словаря случайно срабатывает, поэтому в тестах их берём нарочно.
  Uint8List pieces({int count = 40, int seed = 3}) {
    final random = Random(seed);
    return Uint8List.fromList([
      for (var i = 0; i < count * 20; i++) random.nextInt(256),
    ]);
  }

  /// Кодировка задаётся явно: по умолчанию библиотека пишет строки «как
  /// есть», обрезая каждый символ до байта, и кириллица в имени портится
  /// уже в самой заготовке.
  Uint8List infoDict({String name = 'Some.Game-GROUP', Uint8List? hashes}) =>
      Uint8List.fromList(
        bencode.encode({
          'files': [
            {
              'length': 1234567,
              'path': ['data', 'pak01.dat'],
            },
            {
              'length': 4096,
              'path': ['setup.exe'],
            },
          ],
          'name': name,
          'piece length': 262144,
          'pieces': hashes ?? pieces(),
        }, 'utf-8'),
      );

  group('сборка файла раздачи', () {
    test('info-словарь переносится байт в байт', () {
      final info = infoDict();

      final file = TorrentFile.assemble(info);

      expect(TorrentFile.infoDictIn(file), info);
    });

    // Infohash — это sha1 словаря, а не файла. Перекодируй словарь по дороге,
    // и раздача перестанет совпадать с той, что раздают пиры.
    test('infohash собранного файла равен хешу исходных метаданных', () {
      final info = infoDict();
      final expected = sha1.convert(info).toString();

      final file = TorrentFile.assemble(
        info,
        trackers: [Uri.parse('udp://tracker.example:1337/announce')],
      );

      expect(TorrentFile.infoHash(TorrentFile.infoDictIn(file)!), expected);
    });

    // Трекеры живут в magnet-ссылке, а не в метаданных: не перенеси их —
    // и у задачи останется один DHT, хотя адреса ей дали.
    test('трекеры из ссылки попадают в файл', () {
      final trackers = [
        Uri.parse('udp://one.example:1337/announce'),
        Uri.parse('http://two.example/announce'),
      ];

      final file = TorrentFile.assemble(infoDict(), trackers: trackers);
      // Без указания кодировки декодер отдаёт строки байтами — иначе он
      // споткнулся бы о двоичные хеши кусков в том же файле.
      final decoded = bencode.decode(file) as Map;
      String text(Object? value) => utf8.decode(value! as Uint8List);

      expect(text(decoded['announce']), trackers.first.toString());
      expect(
        (decoded['announce-list'] as List).map(
          (tier) => (tier as List).map(text).toList(),
        ),
        [
          [trackers.first.toString()],
          [trackers.last.toString()],
        ],
      );
    });

    test('без трекеров файл остаётся читаемым', () {
      final file = TorrentFile.assemble(infoDict());
      final decoded = bencode.decode(file) as Map;

      expect(decoded.containsKey('announce'), isFalse);
      expect(decoded['info'], isNotNull);
    });
  });

  group('чтение файла раздачи', () {
    // Границы словаря нельзя искать перебором байтов: `d` и `e` встречаются
    // внутри хешей кусков, и поиск заканчивается посреди двоичных данных.
    test('границы словаря не сбиваются о двоичные хеши кусков', () {
      for (var seed = 0; seed < 25; seed++) {
        final info = infoDict(hashes: pieces(seed: seed));
        final file = TorrentFile.assemble(info);

        expect(
          TorrentFile.infoDictIn(file),
          info,
          reason: 'раздача №$seed разобралась не по границам словаря',
        );
      }
    });

    test('чужой файл не выдаёт себя за торрент', () {
      expect(TorrentFile.infoDictIn(utf8.encode('обычный текст')), isNull);
      expect(TorrentFile.infoDictIn(Uint8List(0)), isNull);
      expect(
        TorrentFile.infoDictIn(Uint8List.fromList(bencode.encode({'a': 1}))),
        isNull,
        reason: 'словарь без info торрентом не является',
      );
    });

    test('оборванный файл не роняет разбор', () {
      final file = TorrentFile.assemble(infoDict());

      expect(TorrentFile.infoDictIn(file.sublist(0, file.length ~/ 2)), isNull);
    });

    // Имена в торрентах — байты, и разбор их как латиницы превращает
    // кириллицу в мусор ещё до того, как её увидит пользователь.
    test('название читается как UTF-8', () {
      expect(TorrentFile.name(infoDict(name: 'Ведьмак 3')), 'Ведьмак 3');
    });
  });

  // Разборщик библиотеки ищет границы info-словаря перебором байтов и на
  // настоящей раздаче промахивается всегда. С промахнувшимся хешем раздачу
  // не узнают ни трекер, ни пир, поэтому его пересчитывают у нас.
  group('infohash разобранной раздачи', () {
    test('совпадает с хешем info-словаря', () {
      for (var seed = 0; seed < 10; seed++) {
        final info = infoDict(hashes: pieces(seed: seed));
        final file = TorrentFile.assemble(info);

        final model = DtorrentEngine.torrentFromBytes(file);

        expect(
          model.infoHash,
          sha1.convert(info).toString(),
          reason: 'раздача №$seed получила чужой infohash',
        );
      }
    });

    test('кириллица в названии переживает разбор', () {
      final file = TorrentFile.assemble(infoDict(name: 'Ведьмак 3'));

      expect(DtorrentEngine.torrentFromBytes(file).name, 'Ведьмак 3');
    });
  });
}
