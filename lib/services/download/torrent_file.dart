import 'dart:convert';
import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart' as bencode;
import 'package:crypto/crypto.dart';

/// Чтение и сборка `.torrent` — то, что нужно знать о формате самому
/// приложению, не спрашивая движок.
///
/// Нужно это в двух местах. Во-первых, magnet-ссылка приносит не файл, а
/// голый info-словарь: чтобы его можно было сохранить, отдать другому
/// клиенту и не выкачивать метаданные заново после перезапуска, вокруг
/// словаря надо собрать настоящий торрент. Во-вторых, infohash — это
/// sha1 **точных байтов** info-словаря, как они лежат в файле; посчитать
/// его по разобранной структуре нельзя, потому что перекодирование меняет
/// байты, а с ними и хеш.
class TorrentFile {
  const TorrentFile._();

  /// Собирает `.torrent` вокруг готового info-словаря.
  ///
  /// Словарь вставляется байт в байт, а не перекодируется: infohash обязан
  /// остаться тем же, иначе трекеры и пиры не узнают раздачу. По этой же
  /// причине ключи выписываются вручную в алфавитном порядке — так требует
  /// bencode, и так собранный файл читается любым клиентом.
  static Uint8List assemble(
    Uint8List infoDict, {
    List<Uri> trackers = const [],
    DateTime? createdAt,
  }) {
    final parts = <List<int>>[
      _dictStart,
      if (trackers.isNotEmpty) ...[
        ..._pair('announce', trackers.first.toString()),
        ..._pair('announce-list', [
          for (final tracker in trackers) [tracker.toString()],
        ]),
      ],
      if (createdAt != null)
        ..._pair('creation date', createdAt.millisecondsSinceEpoch ~/ 1000),
      _encode('info'),
      infoDict,
      _dictEnd,
    ];

    final result = BytesBuilder(copy: false);
    for (final part in parts) {
      result.add(part);
    }
    return result.takeBytes();
  }

  /// Infohash раздачи: sha1 от байтов info-словаря.
  static String infoHash(Uint8List infoDict) =>
      sha1.convert(infoDict).toString();

  /// Вырезает из готового `.torrent` байты его info-словаря.
  ///
  /// Именно вырезает, а не разбирает и собирает заново: у файла, записанного
  /// не по канону, перекодирование дало бы другой infohash — и раздача
  /// перестала бы быть той же самой.
  ///
  /// Возвращает `null`, если это не торрент.
  static Uint8List? infoDictIn(Uint8List torrent) {
    final scanner = _Scanner(torrent);
    try {
      return scanner.findInfo();
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// Название раздачи, прочитанное как UTF-8.
  ///
  /// Имена в торрентах — просто байты, и разбирать их как латиницу значит
  /// превратить кириллицу в мусор.
  static String? name(Uint8List infoDict) {
    final decoded = bencode.decode(infoDict);
    if (decoded is! Map) return null;
    final raw = decoded['name'];
    final bytes = raw is Uint8List
        ? raw
        : (raw is List<int> ? Uint8List.fromList(raw) : null);
    if (bytes == null) return raw is String ? raw : null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return String.fromCharCodes(bytes);
    }
  }

  static List<List<int>> _pair(String key, Object value) => [
    _encode(key),
    _encode(value),
  ];

  /// Кодировку приходится задавать явно: без неё библиотека пишет строки
  /// «как есть», обрезая каждый символ до байта, — и адрес трекера с любой
  /// буквой вне латиницы превратился бы в мусор.
  static Uint8List _encode(Object value) => bencode.encode(value, 'utf-8');

  static final _dictStart = utf8.encode('d');
  static final _dictEnd = utf8.encode('e');
}

/// Обход bencode ради одного: границ значения по ключу `info`.
///
/// Готового способа узнать их нет — декодер отдаёт структуру, а не смещения,
/// и после него исходные байты уже не восстановить.
class _Scanner {
  _Scanner(this.data);

  final Uint8List data;
  int _at = 0;

  static const _d = 0x64; // 'd'
  static const _l = 0x6c; // 'l'
  static const _i = 0x69; // 'i'
  static const _e = 0x65; // 'e'
  static const _colon = 0x3a; // ':'

  Uint8List? findInfo() {
    _expect(_d);
    while (_byte() != _e) {
      final key = _string();
      final start = _at;
      _skipValue();
      if (key == 'info') return Uint8List.sublistView(data, start, _at);
    }
    return null;
  }

  int _byte() {
    if (_at >= data.length) throw const FormatException('торрент оборван');
    return data[_at];
  }

  void _expect(int byte) {
    if (_byte() != byte) throw const FormatException('не похоже на торрент');
    _at++;
  }

  /// Длина строки записана впереди, поэтому «строка» здесь — это любые
  /// байты: имена файлов и хеши кусков ничем не отличаются друг от друга.
  String _string() {
    final start = _at;
    while (_byte() != _colon) {
      _at++;
    }
    final length = int.parse(String.fromCharCodes(data, start, _at));
    _at++;
    final end = _at + length;
    if (end > data.length) throw const FormatException('строка не помещается');
    final value = String.fromCharCodes(data, _at, end);
    _at = end;
    return value;
  }

  void _skipValue() {
    final byte = _byte();
    if (byte == _d || byte == _l) {
      _at++;
      while (_byte() != _e) {
        if (byte == _d) _string();
        _skipValue();
      }
      _at++;
      return;
    }
    if (byte == _i) {
      _at++;
      while (_byte() != _e) {
        _at++;
      }
      _at++;
      return;
    }
    _string();
  }
}
