import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Каждый раздаваемый шрифт лежит с текстом своей лицензии.
///
/// OFL разрешает раздавать шрифт, только приложив её текст. У шрифтов
/// приложения он был, а страница проекта раздаёт свои копии из
/// `site/assets/` — и там не лежало ни одного, а у Nunito Sans для
/// набросков оформления его не было нигде.
void main() {
  for (final folder in ['assets/fonts', 'site/assets']) {
    test('$folder: у каждого шрифта рядом его лицензия', () {
      final fonts = Directory(folder)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'));

      expect(fonts, isNotEmpty);
      expect([
        for (final font in fonts)
          if (!_licensed(font)) font.uri.pathSegments.last,
      ], isEmpty);
    });
  }
}

/// Лицензия лежит на файл или на семейство: у Onest начертания разными
/// файлами (`Onest-Medium.ttf`), а лицензия одна — `OFL-Onest.txt`.
bool _licensed(File font) {
  final name = font.uri.pathSegments.last.replaceAll('.ttf', '');
  final family = name.split('-').first;
  final license = [
    for (final each in {name, family})
      File('${font.parent.path}/OFL-$each.txt'),
  ].firstWhere((f) => f.existsSync(), orElse: () => File(''));
  return license.existsSync() &&
      license.readAsStringSync().contains('SIL OPEN FONT LICENSE Version 1.1');
}
