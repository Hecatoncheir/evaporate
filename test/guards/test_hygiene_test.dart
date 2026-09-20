import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

/// Правила самих тестов: их некому держать, кроме такого же теста.
///
/// Прогон идёт на трёх системах и на чужих машинах, и то, что тест трогает
/// за пределами своей временной папки, однажды окажется чьими-то файлами.
void main() {
  test('блок сохранений в тестах не ходит в настоящие «Документы»', () {
    // По умолчанию он ищет папки сохранений там, где их держат люди:
    // «Документы», «Сохранённые игры», домашняя папка. Обход этих мест на
    // машине прогона не кончается, а на чужой — читает чужое.
    final offenders = <String>[];
    for (final file in dartSources('test')) {
      if (file.path.endsWith('guards/test_hygiene_test.dart')) continue;
      final code = file.code;
      for (var at = code.indexOf('SavesBloc('); at >= 0;) {
        final end = code.indexOf(');', at);
        final call = end < 0 ? code.substring(at) : code.substring(at, end);
        if (!call.contains('saveRoots')) {
          offenders.add('${file.path}: SavesBloc без saveRoots');
        }
        at = code.indexOf('SavesBloc(', at + 1);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'передайте `saveRoots: () => const []` — иначе тест уходит '
          'обходить настоящие папки пользователя:\n  ${offenders.join('\n  ')}',
    );
  });
}
