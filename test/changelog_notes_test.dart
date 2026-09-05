import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  group('верхний раздел годится в описание релиза', () {
    // Версию задаёт тег, и другого её источника в репозитории нет. Значит и
    // проверить до тега можно только одно: что верхний раздел файла — тот,
    // который выпустят следующим, — написан так, как его прочтёт выпуск.
    final changelog = File('CHANGELOG.md').readAsStringSync();

    test('заголовок верхней версии разбирается', () {
      expect(
        latestVersion(changelog),
        isNotNull,
        reason: 'заголовок версии пишется как «## [0.24.0] — 2026-01-01»',
      );
    });

    test('у верхней версии есть текст описания', () {
      final version = latestVersion(changelog)!;

      expect(
        changelogNotes(changelog, version),
        isNotNull,
        reason: 'раздел $version пуст — релиз выйдет без описания',
      );
    });

    // Заголовок раздела написан ссылкой, и без определения внизу он
    // останется на странице квадратными скобками вокруг числа.
    test('на верхнюю версию есть ссылка внизу файла', () {
      final version = latestVersion(changelog)!;

      expect(
        hasLinkReference(changelog, version),
        isTrue,
        reason:
            'добавьте вниз CHANGELOG.md строку '
            '[$version]: https://github.com/Hecatoncheir/evaporate/releases/tag/v$version',
      );
    });
  });

  group('поиск верхней версии', () {
    test('берётся первая сверху, а не самая большая', () {
      expect(latestVersion(sample), '0.8.0');
    });

    // «Не выпущено» стоит выше всех разделов и версией не является.
    test('заголовок без номера пропускается', () {
      expect(
        latestVersion('## [Не выпущено]\n\n## [1.2.3] — 2026-01-01\n'),
        '1.2.3',
      );
    });

    test('файл без версий даёт null', () {
      expect(latestVersion('# История изменений\n'), isNull);
    });
  });
}
