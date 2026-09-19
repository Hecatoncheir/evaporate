import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

/// Каждый ключ ARB кем-то читается.
///
/// Мёртвый ключ не ломает ничего, но переводчик переводит его наравне с
/// живыми, а тот, кто ищет нужную строку, находит две похожие и правит не
/// ту. Строки уходят из интерфейса незаметно — вместе с виджетом, который
/// их показывал, — поэтому и уборку за ними поручаем стражу.
void main() {
  test('в ARB нет ключей, которых никто не читает', () {
    final arb = jsonDecode(
      File('lib/l10n/app_ru.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    // Генерированный `app_localizations*.dart` объявляет все ключи сам и в
    // счёт не идёт. Текст берётся целиком, со строками: ключ часто читается
    // внутри подстановки — `'${l.filesCount(n)}'`.
    final code = dartSources(
      'lib',
      skip: (path) => path.contains('/l10n/app_localizations'),
    ).map((file) => file.text).join('\n');

    final unused = [
      for (final key in arb.keys)
        if (!key.startsWith('@') && !RegExp('\\.$key\\b').hasMatch(code)) key,
    ];

    expect(
      unused,
      isEmpty,
      reason: 'уберите эти ключи из обоих ARB-файлов вместе с их «@»-описанием',
    );
  });
}
