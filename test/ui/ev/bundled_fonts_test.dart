import 'dart:io';

import 'package:evaporate/ui/ev/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Шрифты каркаса лежат в сборке, а не скачиваются.
///
/// Прототип брал их через `google_fonts`, и с П1 приложение на каждой
/// машине шло за ними к fonts.gstatic.com — мимо согласия человека и мимо
/// временного дома `--smoke`, в настоящую папку данных, — а без сети
/// рисовало каркас запасным шрифтом.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

  /// Семейство → его файлы из раздела `flutter.fonts`.
  final bundled = {
    for (final family in (pubspec['flutter'] as YamlMap)['fonts'] as YamlList)
      (family as YamlMap)['family'] as String: [
        for (final font in family['fonts'] as YamlList)
          (font as YamlMap)['asset'] as String,
      ],
  };

  test('google_fonts нет ни в зависимостях, ни в коде', () {
    expect(
      (pubspec['dependencies'] as YamlMap).keys,
      isNot(contains('google_fonts')),
    );
    final importers = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('package:google_fonts'))
          file.path,
    ];
    expect(importers, isEmpty);
  });

  test('каждый стиль каркаса набран семейством из сборки', () {
    const type = EvType(Colors.white, Colors.white, Colors.white, Colors.white);
    const base = TextStyle();
    final styles = [
      type.display(40),
      type.displayBold(40),
      type.section,
      type.title,
      type.body,
      type.bodySmall,
      type.label,
      type.data,
      type.dataStrong,
      type.big(30),
      type.ui(base),
      type.dsp(base),
      type.mono(base),
    ];
    for (final style in styles) {
      expect(bundled.keys, contains(style.fontFamily));
    }
    for (final files in bundled.values) {
      for (final asset in files) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
  });

  // Onest лежит тремя начертаниями, а не вариативным файлом: проверяем,
  // что вес выбирает файл, а не подделывается движком.
  test('Onest отвечает на вес своими начертаниями', () async {
    final loader = FontLoader(EvType.uiFamily);
    for (final asset in bundled[EvType.uiFamily]!) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();

    double width(FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Испарение сохранений 123',
          style: TextStyle(
            fontFamily: EvType.uiFamily,
            fontSize: 40,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      return painter.width;
    }

    final regular = width(FontWeight.w400);
    final medium = width(FontWeight.w500);
    final semibold = width(FontWeight.w600);
    expect(medium, greaterThan(regular));
    expect(semibold, greaterThan(medium));
  });
}
