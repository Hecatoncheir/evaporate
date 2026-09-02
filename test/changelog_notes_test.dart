import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../tool/changelog_notes.dart';

/// Описание релиза берётся из истории изменений, а не пишется заново.
void main() {
  const sample = '''
# История изменений

Формат следует Keep a Changelog.

## [0.8.0] — 2026-09-03

### Добавлено

- Перетаскивание в окно библиотеки.

## [0.7.0] — 2026-09-02

### Добавлено

- Папка сохранений по запуску игры.

[0.8.0]: https://example.com/tag/v0.8.0
[0.7.0]: https://example.com/tag/v0.7.0
''';

  test('раздел версии берётся целиком и без заголовка', () {
    final notes = changelogNotes(sample, '0.8.0');

    expect(notes, contains('### Добавлено'));
    expect(notes, contains('Перетаскивание в окно библиотеки.'));
    expect(notes, isNot(contains('0.8.0')));
  });

  // Иначе в описание одной версии уехала бы вся история до самого низа.
  test('соседняя версия в описание не попадает', () {
    final notes = changelogNotes(sample, '0.8.0');

    expect(notes, isNot(contains('Папка сохранений')));
    expect(notes, isNot(contains('0.7.0')));
  });

  // Ссылки идут сплошным блоком в конце, сразу за последним разделом.
  test('определения ссылок в описание не попадают', () {
    final notes = changelogNotes(sample, '0.7.0');

    expect(notes, contains('Папка сохранений'));
    expect(notes, isNot(contains('https://example.com')));
  });

  test('края описания не обрастают пустыми строками', () {
    final notes = changelogNotes(sample, '0.8.0')!;

    expect(notes, notes.trim());
  });

  // Пустая строка вместо описания — это релиз без описания, которого
  // никто не заметит. Пусть лучше будет видно, что раздела нет.
  test('пропущенная версия даёт null, а не пустоту', () {
    expect(changelogNotes(sample, '9.9.9'), isNull);
  });

  test('раздел без текста считается отсутствующим', () {
    expect(changelogNotes('## [1.0.0] — 2026-01-01\n\n', '1.0.0'), isNull);
  });

  // Версия ищется по началу строки, а дата у каждой своя.
  test('дата в заголовке разбору не мешает', () {
    expect(changelogNotes('## [1.0.0]\n\n- Первая.\n', '1.0.0'), '- Первая.');
  });

  // Страж на будущее: тег выпускают по версии из pubspec, и если раздела
  // для неё нет, CI заведёт черновик вместо релиза — а узнать об этом лучше
  // здесь, чем по факту молчаливого выпуска.
  test('у текущей версии из pubspec есть раздел в CHANGELOG', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final version = (pubspec['version'] as String).split('+').first;

    final notes = changelogNotes(
      File('CHANGELOG.md').readAsStringSync(),
      version,
    );

    expect(
      notes,
      isNotNull,
      reason: 'подняли версию — опишите её в CHANGELOG.md',
    );
  });
}
