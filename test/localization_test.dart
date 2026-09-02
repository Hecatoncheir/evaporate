import 'dart:convert';
import 'dart:io';

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/app_settings.dart';
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
}
