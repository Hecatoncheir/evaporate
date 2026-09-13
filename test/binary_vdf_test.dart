import 'dart:convert';

import 'package:evaporate/services/launch/binary_vdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Пустой список ярлыков — ровно то, что Steam кладёт, пока сторонних игр
  /// нет: карта `shortcuts` без единой записи.
  final empty = <int>[
    0, ...utf8.encode('shortcuts'), 0, //
    8, 8,
  ];

  /// Настоящая запись Steam: тот же набор полей и тот же их порядок, снятый
  /// с файла, который Steam написал сам. Путь и название — нейтральные.
  ///
  /// Здесь важен каждый байт, поэтому список записан числами, а не собран
  /// нашим же кодом: фикстура, построенная тем, что она проверяет, не
  /// проверяет ничего.
  const steamWrote = <int>[
    0, 115, 104, 111, 114, 116, 99, 117, 116, 115, 0, 0, 48, 0, 2, 97, //
    112, 112, 105, 100, 0, 200, 19, 126, 208, 1, 65, 112, 112, 78, 97,
    109, 101, 0, 208, 159, 208, 190, 209, 128, 209, 130, 208, 176,
    208, 187, 209, 140, 208, 189, 208, 176, 209, 143, 32, 208, 184,
    208, 179, 209, 128, 208, 176, 0, 1, 69, 120, 101, 0, 34, 67, 58,
    92, 71, 97, 109, 101, 115, 92, 80, 111, 114, 116, 97, 108, 92,
    112, 111, 114, 116, 97, 108, 46, 101, 120, 101, 34, 0, 1, 83, 116,
    97, 114, 116, 68, 105, 114, 0, 67, 58, 92, 71, 97, 109, 101, 115,
    92, 80, 111, 114, 116, 97, 108, 92, 0, 1, 105, 99, 111, 110, 0, 0,
    1, 83, 104, 111, 114, 116, 99, 117, 116, 80, 97, 116, 104, 0, 0,
    1, 76, 97, 117, 110, 99, 104, 79, 112, 116, 105, 111, 110, 115, 0,
    0, 2, 73, 115, 72, 105, 100, 100, 101, 110, 0, 0, 0, 0, 0, 2, 65,
    108, 108, 111, 119, 68, 101, 115, 107, 116, 111, 112, 67, 111,
    110, 102, 105, 103, 0, 1, 0, 0, 0, 2, 65, 108, 108, 111, 119, 79,
    118, 101, 114, 108, 97, 121, 0, 1, 0, 0, 0, 2, 79, 112, 101, 110,
    86, 82, 0, 0, 0, 0, 0, 2, 68, 101, 118, 107, 105, 116, 0, 0, 0, 0,
    0, 1, 68, 101, 118, 107, 105, 116, 71, 97, 109, 101, 73, 68, 0, 0,
    2, 68, 101, 118, 107, 105, 116, 79, 118, 101, 114, 114, 105, 100,
    101, 65, 112, 112, 73, 68, 0, 0, 0, 0, 0, 2, 76, 97, 115, 116, 80,
    108, 97, 121, 84, 105, 109, 101, 0, 0, 0, 0, 0, 1, 70, 108, 97,
    116, 112, 97, 107, 65, 112, 112, 73, 68, 0, 0, 1, 115, 111, 114,
    116, 97, 115, 0, 0, 0, 116, 97, 103, 115, 0, 8, 8, 8, 8,
  ];

  test('пустой список ярлыков читается и пишется так же, как у Steam', () {
    final document = BinaryVdf.decode(empty);

    expect(document.keys, ['shortcuts']);
    expect(document['shortcuts'], isEmpty);
    expect(BinaryVdf.encode(document), empty);
  });

  test('запись Steam переживает разбор и сборку байт в байт', () {
    final document = BinaryVdf.decode(steamWrote);
    final shortcuts = document['shortcuts']! as Map<String, Object>;
    final first = shortcuts['0']! as Map<String, Object>;

    expect(first['appid'], -797043768);
    expect(first['AppName'], 'Портальная игра');
    // Steam берёт в кавычки `Exe`, но не `StartDir`. Отличие видно только на
    // настоящем файле, а ярлык с лишними кавычками в рабочей папке Steam
    // молча не запускает.
    expect(first['Exe'], r'"C:\Games\Portal\portal.exe"');
    expect(first['StartDir'], r'C:\Games\Portal\');
    expect(first['tags'], isEmpty);

    expect(
      BinaryVdf.encode(document),
      steamWrote,
      reason: 'файл принадлежит Steam — наша запись обязана совпасть с его',
    );
  });

  test('порядок полей сохраняется, а не пересортировывается', () {
    final document = BinaryVdf.decode(steamWrote);
    final shortcuts = document['shortcuts']! as Map<String, Object>;
    final first = shortcuts['0']! as Map<String, Object>;

    expect(first.keys.take(4), ['appid', 'AppName', 'Exe', 'StartDir']);
    expect(first.keys.last, 'tags');
  });

  test('название с кириллицей и эмодзи переживает круг', () {
    final document = <String, Object>{
      'shortcuts': <String, Object>{
        '0': <String, Object>{
          'appid': -1,
          'AppName': 'Ведьмак 3: Дикая Охота 🎮',
          'tags': <String, Object>{'0': 'своё'},
        },
      },
    };

    final again = BinaryVdf.decode(BinaryVdf.encode(document));
    final first =
        (again['shortcuts']! as Map<String, Object>)['0']!
            as Map<String, Object>;
    expect(first['AppName'], 'Ведьмак 3: Дикая Охота 🎮');
    expect(first['appid'], -1);
    expect(first['tags'], {'0': 'своё'});
  });

  // Читаем мы затем, чтобы переписать. Пустая карта вместо непонятого куска
  // означала бы, что человеку сотрут его собственные ярлыки, и никто об этом
  // не узнает.
  test('непонятый байт отказывает, а не возвращает пустой список', () {
    final broken = <int>[
      0, ...utf8.encode('shortcuts'), 0, //
      0x07, ...utf8.encode('что-то новое'), 0, 1, 2, 3, 4, 5, 6, 7, 8,
      8, 8,
    ];

    expect(() => BinaryVdf.decode(broken), throwsFormatException);
  });

  test('оборванный файл отказывает, а не отдаёт прочитанное', () {
    final truncated = <int>[
      0, ...utf8.encode('shortcuts'), 0, //
      0, ...utf8.encode('0'), 0,
      2, ...utf8.encode('appid'), 0, 1, 2, // число обрывается на середине
    ];

    expect(() => BinaryVdf.decode(truncated), throwsFormatException);
  });

  test('строка без завершающего нуля отказывает', () {
    expect(
      () => BinaryVdf.decode(<int>[0, ...utf8.encode('shortcuts')]),
      throwsFormatException,
    );
  });

  test('пустой файл — это «ярлыков нет», а не поломка', () {
    expect(BinaryVdf.decode(const []), isEmpty);
  });

  test('число, не влезающее в 32 бита, не уходит на диск обрезанным', () {
    expect(
      () => BinaryVdf.encode(<String, Object>{'appid': 2147483648}),
      throwsFormatException,
    );
  });
}
