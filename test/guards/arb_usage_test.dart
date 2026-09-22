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

    final read = keysRead(code);
    final unused = [
      for (final key in arb.keys)
        if (!key.startsWith('@') && !read.contains(key)) key,
    ];

    expect(
      unused,
      isEmpty,
      reason: 'уберите эти ключи из обоих ARB-файлов вместе с их «@»-описанием',
    );
  });

  // Сломанная проверка — вечная зелень. Прежде ключ считался живым по
  // любому `.key` в коде, и `source` жил за счёт `download.source`, а не
  // перевода: таких ключей-однофамильцев с полями около десятка.
  group('страж ловит нарушение', () {
    const reads = {
      'l.': 'Text(l.source)',
      '_l.': 'throw X(_l.source);',
      'L.of(context).': 'L.of(context).source',
      'L.of(context) с переносом': 'L\n    .of(context)\n    .source(a)',
      'функция переводов': '_defaultLocalizations().source',
      'в подстановке': r"'${l.source}'",
    };
    for (final MapEntry(key: shape, value: code) in reads.entries) {
      test('читает: $shape', () => expect(readsKey(code, 'source'), isTrue));
    }

    test('поле однофамильца — не чтение перевода', () {
      expect(readsKey('game.download.source', 'source'), isFalse);
      expect(readsKey('l.sourceTitle', 'source'), isFalse);
    });
  });
}

/// Кто читает переводы: `l`, `_l`, `L.of(context)` (в том числе разбитый
/// переносами) и функции вида `localizations()` — у блоков и сервисов
/// своего `BuildContext` нет.
const _receiver =
    r'(?:\bl|\b_l|\bL\s*\.\s*of\(\s*context\s*\)|\w*[lL]ocalizations\(\))';

/// Имена, которые читают у переводов, — одним проходом: регулярка на
/// каждый из пятисот ключей шла по мегабайту кода полторы минуты.
Set<String> keysRead(String code) => {
  for (final match in RegExp(
    '$_receiver'
    r'\s*\.\s*(\w+)',
  ).allMatches(code))
    match.group(1)!,
};

/// Читается ли ключ [key] переводом, а не одноимённым полем чужого объекта.
bool readsKey(String code, String key) => keysRead(code).contains(key);
