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
    final offenders = [
      for (final file in dartSources('test'))
        if (!file.path.endsWith('guards/test_hygiene_test.dart'))
          ...savesBlocsWithoutRoots(file),
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'передайте `saveRoots: () => const []` — иначе тест уходит '
          'обходить настоящие папки пользователя:\n  ${offenders.join('\n  ')}',
    );
  });

  // Сломанная проверка — вечная зелень.
  group('страж ловит нарушение', () {
    SourceFile file(String code) => SourceFile('test/x_test.dart', code);

    test('блок без корней', () {
      final code = file('final b = SavesBloc(paths: p, library: l);');
      expect(savesBlocsWithoutRoots(code), hasLength(1));
    });

    test('блок с корнями', () {
      final code = file(
        'final b = SavesBloc(paths: p, saveRoots: () => const []);',
      );
      expect(savesBlocsWithoutRoots(code), isEmpty);
    });

    test('корни у соседнего вызова не засчитываются', () {
      // Граница вызова — его закрывающая скобка, а не первое `);` в файле:
      // у вложенного вызова оно наступает раньше.
      final code = file('''
final a = SavesBloc(paths: p, settings: Settings(x));
final b = SavesBloc(paths: p, saveRoots: () => const []);
''');
      expect(savesBlocsWithoutRoots(code), hasLength(1));
    });
  });
}

/// Вызовы `SavesBloc(` без `saveRoots` внутри своих скобок.
Iterable<String> savesBlocsWithoutRoots(SourceFile file) sync* {
  final code = file.code;
  for (var at = code.indexOf('SavesBloc('); at >= 0;) {
    final open = at + 'SavesBloc'.length;
    var depth = 0;
    var end = open;
    for (; end < code.length; end++) {
      if (code[end] == '(') depth++;
      if (code[end] == ')' && --depth == 0) break;
    }
    if (!code.substring(open, end).contains('saveRoots')) {
      yield '${file.path}: SavesBloc без saveRoots';
    }
    at = code.indexOf('SavesBloc(', at + 1);
  }
}
