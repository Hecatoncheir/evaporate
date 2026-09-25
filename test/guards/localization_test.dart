import 'dart:convert';
import 'dart:io';

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/ui/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import 'prototype_strings.dart';

void main() {
  Map<String, dynamic> arb(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;

  group('переводы', () {
    // Пропущенный ключ во втором языке — самая частая ошибка при переводе:
    // приложение соберётся, а строка молча останется на чужом языке.
    test('английский покрывает все ключи русского', () {
      final ru = arb('ru').keys.where((k) => !k.startsWith('@')).toSet();
      final en = arb('en').keys.where((k) => !k.startsWith('@')).toSet();

      expect(
        ru.difference(en),
        isEmpty,
        reason: 'нет английского перевода для этих ключей',
      );
      expect(
        en.difference(ru),
        isEmpty,
        reason: 'английские ключи без русского оригинала',
      );
    });

    test('пустых переводов нет', () {
      for (final lang in ['ru', 'en']) {
        arb(lang).forEach((key, value) {
          if (key.startsWith('@')) return;
          expect(
            (value as String).trim(),
            isNotEmpty,
            reason: 'пустой перевод $key в $lang',
          );
        });
      }
    });

    // Если в русской строке есть подстановка, она обязана быть и в переводе,
    // иначе значение просто пропадёт из текста.
    test('подстановки совпадают в обоих языках', () {
      final ru = arb('ru');
      final en = arb('en');

      for (final key in ru.keys.where((k) => !k.startsWith('@'))) {
        expect(
          placeholdersIn(en[key] as String),
          placeholdersIn(ru[key] as String),
          reason: 'подстановки разошлись в ключе $key',
        );
      }
    });

    // Формы числа у языков разные: у русского их четыре, у английского
    // две. Проверяем не текст, а то, что склонение вообще работает, —
    // иначе «1 файлов» вернулось бы незамеченным.
    test('число склоняется по правилам своего языка', () {
      final ru = LRu();
      final en = LEn();

      expect(ru.filesCount(1), '1 файл');
      expect(ru.filesCount(3), '3 файла');
      expect(ru.filesCount(7), '7 файлов');
      expect(en.filesCount(1), '1 file');
      expect(en.filesCount(3), '3 files');
    });
  });

  group('языки приложения', () {
    test('поддерживаются ровно те, что объявлены в настройках', () {
      final codes = L.supportedLocales.map((l) => l.languageCode).toSet();

      expect(codes, Appearance.supportedLocales.toSet());
    });

    test('незнакомый язык читается как системный', () {
      final restored = AppSettings.fromJson(const {
        'installDir': '/games',
        'locale': 'kl',
      }, '/games');

      expect(restored.appearance.locale, isNull);
    });

    test('выбранный язык переживает запись и чтение', () {
      for (final code in Appearance.supportedLocales) {
        final settings = const AppSettings(installDir: '/games')
            .withAppearance((a) => a.copyWith(locale: code));

        expect(
          AppSettings.fromJson(settings.toJson(), '/games').appearance.locale,
          code,
        );
      }
    });

    test('по умолчанию язык не задан — берётся системный', () {
      expect(const AppSettings(installDir: '/games').appearance.locale, isNull);
    });
  });

  group('строки доходят до интерфейса', () {
    Future<String> labelIn(WidgetTester tester, Locale locale) async {
      late String seen;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: locale,
          home: Builder(
            builder: (context) {
              seen = L.of(context).appearance;
              return const SizedBox();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('русский и английский дают разный текст', (tester) async {
      final ru = await labelIn(tester, const Locale('ru'));
      final en = await labelIn(tester, const Locale('en'));

      expect(ru, 'Оформление');
      expect(en, 'Appearance');
    });

    testWidgets('незнакомый язык откатывается к первому', (tester) async {
      final fallback = await labelIn(tester, const Locale('kl'));

      expect(fallback, isNotEmpty);
    });
  });

  // Метка правила — ключ сопоставления между устройствами, а не подпись.
  // Переведись она, снимок с русской машины перестал бы сходиться с
  // правилом на английской, и заметить это было бы почти невозможно.
  group('метка правила не переводится', () {
    test('значение по умолчанию одинаково на всех языках', () {
      expect(SavePathRule.defaultLabel, isNotEmpty);
      expect(
        LRu().saves == LEn().saves,
        isFalse,
        reason: 'подписи переводятся, а ключ — нет: в этом весь смысл',
      );
    });

    test('показывается переведённой, а хранится как есть', () {
      expect(ruleLabelText(LEn(), SavePathRule.defaultLabel), LEn().saves);
      expect(ruleLabelText(LRu(), SavePathRule.defaultLabel), LRu().saves);
    });

    test('вписанное человеком не трогаем', () {
      expect(ruleLabelText(LEn(), 'Мои слоты'), 'Мои слоты');
      expect(ruleLabelText(LRu(), 'Profile 2'), 'Profile 2');
    });
  });

  // Строку легко вписать прямо в виджет и не заметить, что она осталась
  // непереведённой: приложение соберётся, тесты пройдут, и обнаружится это
  // только у человека с английским интерфейсом.
  test('в слое интерфейса не осталось непереведённых строк', () {
    final offenders = dartSources(
      'lib/ui',
      skip: isPrototypeCode,
    ).expand(cyrillicStrings).toList();

    expect(
      offenders,
      isEmpty,
      reason: 'эти строки нужно вынести в lib/l10n/app_ru.arb',
    );
  });

  // Прототип перенесён со своими строками по-русски (0013), и английский
  // интерфейс его пока не видит. Строки уходят в ARB по мере того, как экран
  // подключается к блокам, — число в файле может только убывать.
  test('строк прототипа по-русски не прибавляется', () {
    expectRatchet(
      found: [
        for (final file in dartSources('lib/ui/ev'))
          if (cyrillicStrings(file).length case final n when n > 0)
            '${file.path}: $n',
      ],
      known: prototypeStrings,
      rule: 'строку прототипа — в lib/l10n/app_ru.arb и app_en.arb',
    );
  });

  // Текст этих исключений человек читает как есть: сообщением, отказом на
  // карточке. Написанный по месту, он доходил до английского интерфейса
  // по-русски — «Сервер ответил 404», «папки нет». Слова — из ARB, а где
  // языка нет (изолят, статика), исключение несёт причину.
  test('исключения, которые читает человек, не пишут по-русски по месту', () {
    final offenders = dartSources(
      'lib',
      skip: (path) => path.contains('/l10n/app_localizations'),
    ).expand(russianHumanExceptions).toList();

    expect(
      offenders,
      isEmpty,
      reason: 'слова — в lib/l10n/app_ru.arb, а исключению — причина',
    );
  });

  // Журнальные подписи моделей русские всегда — на то они и журнальные.
  // Страж кириллицы их не видит: литерал лежит в `lib/models`, а в
  // интерфейс он попадал чтением `.label` — «Source: Локальная папка».
  // Поэтому они названы `logLabel`, и интерфейсу это имя запрещено.
  test('интерфейс не показывает журнальных подписей моделей', () {
    final offenders = [
      for (final file in dartSources('lib/ui'))
        for (final match in _logLabel.allMatches(file.code))
          '${file.path}:${'\n'.allMatches(file.code.substring(0, match.start)).length + 1}',
    ];
    expect(offenders, isEmpty, reason: 'подпись для показа — в ui/labels.dart');
    expect(_logLabel.hasMatch('Text(source.logLabel)'), isTrue);
  });

  // Сломанная проверка — вечная зелень. Прежняя искала только одинарные
  // кавычки построчно: строка в двойных, в тройных кавычках или
  // разбитая на две строки проходила, а хвостовой комментарий с
  // апострофом и русским словом валил прогон.
  group('страж ловит нарушение', () {
    SourceFile file(String code) => SourceFile('lib/ui/x.dart', code);

    const strings = {
      'одинарные кавычки': "Text('Привет')",
      'двойные кавычки': 'Text("Привет")',
      'тройные кавычки': "Text('''\nПривет\n''')",
      'подстановка рядом': r"Text('${n} файлов')",
    };
    for (final MapEntry(key: shape, value: code) in strings.entries) {
      test(shape, () => expect(cyrillicStrings(file(code)), hasLength(1)));
    }

    test('комментарии по-русски — норма', () {
      const code = '''
// Подпись берётся из ARB.
/// Документ по-русски.
final a = 'ok'; // хвост с 'апострофом' по-русски
/* Блок
   по-русски */
''';
      expect(cyrillicStrings(file(code)), isEmpty);
    });

    // Разбор терял приставку сырой строки и после каждой такой строки
    // смотрел на знак левее, чем текст.
    test('сырая строка не сдвигает разбор', () {
      const code = r"final re = r'\d'; Text('Привет');";
      expect(file(code).code, hasLength(code.length));
      expect(cyrillicStrings(file(code)), hasLength(1));
    });

    const exceptions = {
      'русская строка': "throw SaveException('Сломалось');",
      'подстановка рядом': r"throw FileManagerException('$path — нет');",
      'именованный конструктор':
          "throw const FileManagerException.failed(p, 'нет связи');",
      'строка на другой строке': "throw SaveException(\n  'Сломалось',\n);",
      'после сырой строки':
          r"final a = r'\d'; throw UpdateCheckException('Сбой');",
    };
    for (final MapEntry(key: shape, value: code) in exceptions.entries) {
      test(
        'исключение: $shape',
        () => expect(russianHumanExceptions(file(code)), hasLength(1)),
      );
    }

    const allowed = {
      'слова из переводов': 'throw SaveException(_l.saveNothingFound);',
      'журнальное исключение': "throw StateError('не был вызван');",
      'русский комментарий за скобкой':
          'throw SaveException(error.message); // Сломалось',
    };
    for (final MapEntry(key: shape, value: code) in allowed.entries) {
      test(
        'не исключение: $shape',
        () => expect(russianHumanExceptions(file(code)), isEmpty),
      );
    }
  });
}

/// Строки с русскими буквами: `путь:строка`.
///
/// Ищет по разбору, а не по строкам файла: в [SourceFile.code] содержимое
/// строк и комментарии заменены пробелами, а кавычки оставлены. Русская
/// буква в тексте, на месте которой в разборе пробел, стоит в строке, если
/// слева от неё — кавычка, и в комментарии, если что-то другое.
Iterable<String> cyrillicStrings(SourceFile file) sync* {
  final reported = <int>{};
  for (final at in _cyrillicInStrings(file)) {
    final line = _lineOf(file, at);
    if (reported.add(line)) yield '${file.path}:$line';
  }
}

/// Где в тексте стоят русские буквы внутри строк.
Iterable<int> _cyrillicInStrings(SourceFile file) sync* {
  final cyrillic = RegExp('[а-яёА-ЯЁ]');
  for (final match in cyrillic.allMatches(file.text)) {
    var k = match.start - 1;
    while (k >= 0 && (file.code[k] == ' ' || file.code[k] == '\n')) {
      k--;
    }
    if (k >= 0 && const {"'", '"'}.contains(file.code[k])) yield match.start;
  }
}

int _lineOf(SourceFile file, int at) =>
    '\n'.allMatches(file.text.substring(0, at)).length + 1;

/// Исключения, текст которых показывают человеку как есть.
///
/// Поимённо, а не все подряд: `StateError` или `FormatException` с русским
/// текстом законны — они уходят в журнал, а не на экран.
const humanExceptions = [
  'AddGameRejected',
  'DownloadEngineException',
  'FileManagerException',
  'LaunchException',
  'SaveException',
  'SaveNothingFoundException',
  'SteamLookupException',
  'SteamShortcutException',
  'UpdateCheckException',
  'UpdateException',
];

/// Такие исключения с русской строкой в аргументах: `путь:строка`.
Iterable<String> russianHumanExceptions(SourceFile file) sync* {
  final russian = _cyrillicInStrings(file).toList();
  final call = RegExp('\\b(?:${humanExceptions.join('|')})(?:\\.\\w+)?\\(');
  for (final match in call.allMatches(file.code)) {
    final end = _closingParen(file.code, match.end - 1);
    if (russian.any((at) => at > match.end && at < end)) {
      yield '${file.path}:${_lineOf(file, match.start)}';
    }
  }
}

/// Где закрывается скобка, открытая в [open]. Строки в разборе затёрты, и
/// скобка внутри них счёт не собьёт.
int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')' && --depth == 0) return i;
  }
  return code.length;
}

/// Имена подстановок в строке ARB, включая ICU.
///
/// Обычная подстановка — `{name}`, но у множественного числа она стоит
/// иначе: `{count, plural, one{…}}`. Ищи страж только первую — и перевод,
/// где число названо лишь во главе ICU, выглядел бы потерявшим его.
Set<String> placeholdersIn(String text) => {
  for (final match in RegExp(r'\{(\w+)\}').allMatches(text)) match.group(1)!,
  for (final match in RegExp(
    r'\{(\w+),\s*(?:plural|select|date|time)',
  ).allMatches(text))
    match.group(1)!,
};

final _logLabel = RegExp(r'\.logLabel\b');
