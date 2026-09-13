import 'dart:convert';
import 'dart:typed_data';

/// Разбор двоичного формата Valve — того, которым Steam пишет
/// `shortcuts.vdf`, список сторонних игр в библиотеке.
///
/// Текстовый [Vdf] тут не подходит: это другой формат, не другой синтаксис.
/// Запись — байт типа, имя ключа с нулём на конце, затем значение:
///
/// ```
/// 0x00  вложенная карта, закрывается 0x08
/// 0x01  строка UTF-8 с нулём на конце
/// 0x02  знаковое 32-битное число, младший байт первым
/// 0x08  конец карты
/// ```
///
/// Документ целиком — одна карта (`shortcuts`), и после её `0x08` идёт ещё
/// один: им закрывается сам документ. Пустой список выглядит так:
/// `00 "shortcuts" 00 08 08` — тринадцать байт.
///
/// Порядок ключей значим и сохраняется: `Map` в Dart помнит порядок
/// вставки, и разбор с обратной сборкой дают файл байт в байт. Это не
/// придирка к аккуратности — файл принадлежит Steam, и чем меньше наша
/// запись от его собственной отличается, тем меньше поводов гадать, из-за
/// чего он повёл себя не так.
class BinaryVdf {
  const BinaryVdf._();

  static const _map = 0x00;
  static const _string = 0x01;
  static const _int32 = 0x02;
  static const _end = 0x08;

  /// Разбирает документ в дерево карт: значения — [String], [int] или
  /// вложенная `Map<String, Object>`.
  ///
  /// **Бросает на всём, чего не понимает, — и это намеренно.** Текстовый
  /// [Vdf] на непонятном возвращает пустую карту, потому что читает чужой
  /// файл и только читает. Здесь мы читаем, чтобы потом **переписать**, а
  /// пустая карта вместо непонятого куска означала бы, что мы сотрём
  /// человеку его собственные ярлыки и даже не заметим. Не понял — не
  /// трогай.
  static Map<String, Object> decode(List<int> bytes) {
    // Нулевой длины файл — это «ярлыков нет», а не поломка: терять тут
    // нечего, и отказ лишь помешал бы завести первый.
    if (bytes.isEmpty) return <String, Object>{};

    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final reader = _Reader(data);
    final document = reader.readMap(depth: 0);
    if (!reader.atEnd) {
      throw const FormatException('После документа остались лишние байты');
    }
    return document;
  }

  /// Собирает документ обратно в байты.
  static Uint8List encode(Map<String, Object> document) {
    final out = BytesBuilder();
    _writeEntries(out, document);
    out.addByte(_end);
    return out.toBytes();
  }

  static void _writeEntries(BytesBuilder out, Map<String, Object> map) {
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map<String, Object>) {
        out.addByte(_map);
        _writeString(out, entry.key);
        _writeEntries(out, value);
        out.addByte(_end);
      } else if (value is String) {
        out.addByte(_string);
        _writeString(out, entry.key);
        _writeString(out, value);
      } else if (value is int) {
        // Число здесь ровно 32-битное и знаковое. Молча обрезать всё, что
        // не влезло, нельзя: обрезанный `appid` — это чужой ярлык.
        if (value < -2147483648 || value > 2147483647) {
          throw FormatException('Число не помещается в 32 бита: $value');
        }
        out.addByte(_int32);
        _writeString(out, entry.key);
        final number = ByteData(4)..setInt32(0, value, Endian.little);
        out.add(number.buffer.asUint8List());
      } else {
        throw FormatException('Нечего писать для ${entry.key}: $value');
      }
    }
  }

  static void _writeString(BytesBuilder out, String value) {
    out.add(utf8.encode(value));
    out.addByte(0);
  }
}

class _Reader {
  _Reader(this.data);

  final Uint8List data;
  var _offset = 0;

  bool get atEnd => _offset >= data.length;

  /// Вложенность ограничена: файл чужой, а испорченный может свернуться в
  /// тысячи вложенных карт и положить разбор вместе с приложением.
  static const _maxDepth = 16;

  Map<String, Object> readMap({required int depth}) {
    if (depth > _maxDepth) {
      throw const FormatException('Слишком глубокая вложенность');
    }
    final map = <String, Object>{};
    while (true) {
      if (atEnd) throw const FormatException('Документ оборван');
      final type = data[_offset++];
      if (type == BinaryVdf._end) return map;

      final key = _readString();
      switch (type) {
        case BinaryVdf._map:
          map[key] = readMap(depth: depth + 1);
        case BinaryVdf._string:
          map[key] = _readString();
        case BinaryVdf._int32:
          if (_offset + 4 > data.length) {
            throw const FormatException('Число оборвано');
          }
          map[key] = ByteData.sublistView(
            data,
            _offset,
            _offset + 4,
          ).getInt32(0, Endian.little);
          _offset += 4;
        default:
          throw FormatException(
            'Неизвестный тип 0x${type.toRadixString(16)} у «$key»',
          );
      }
    }
  }

  String _readString() {
    final end = data.indexOf(0, _offset);
    if (end < 0) throw const FormatException('Строка без завершающего нуля');
    final value = utf8.decode(data.sublist(_offset, end), allowMalformed: true);
    _offset = end + 1;
    return value;
  }
}
