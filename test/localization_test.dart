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
      final braces = RegExp(r'\{(\w+)\}');

      for (final key in ru.keys.where((k) => !k.startsWith('@'))) {
        final inRu = braces
            .allMatches(ru[key] as String)
            .map((m) => m.group(1))
            .toSet();
        final inEn = braces
            .allMatches(en[key] as String)
            .map((m) => m.group(1))
            .toSet();

        expect(inEn, inRu, reason: 'подстановки разошлись в ключе $key');
      }
    });
  });

  group('языки приложения', () {
    test('поддерживаются ровно те, что объявлены в настройках', () {
      final codes = L.supportedLocales.map((l) => l.languageCode).toSet();

      expect(codes, AppSettings.supportedLocales.toSet());
    });

    test('незнакомый язык читается как системный', () {
      final restored = AppSettings.fromJson({
        'installDir': '/games',
        'locale': 'kl',
      }, '/games');

      expect(restored.locale, isNull);
    });

    test('выбранный язык переживает запись и чтение', () {
      for (final code in AppSettings.supportedLocales) {
        final settings = const AppSettings(installDir: '/games')
            .copyWith(locale: code);

        expect(AppSettings.fromJson(settings.toJson(), '/games').locale, code);
      }
    });

    test('по умолчанию язык не задан — берётся системный', () {
      expect(const AppSettings(installDir: '/games').locale, isNull);
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
    final offenders = <String>[];
    final literal = RegExp(r"'[^']*[а-яёА-ЯЁ][^']*'");

    for (final entity in Directory('lib/ui').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        final code = line.trimLeft();
        // Комментарии по-русски — это норма, речь только о строках.
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (literal.hasMatch(line)) offenders.add('${entity.path}: $code');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'эти строки нужно вынести в lib/l10n/app_ru.arb',
    );
  });
}
