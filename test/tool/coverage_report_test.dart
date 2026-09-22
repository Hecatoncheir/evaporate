import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

void main() {
  test('генерация исключается, повторные записи объединяются', () {
    final files = parseCoverage('''
SF:/checkout/lib/core/store.dart
DA:1,0
DA:2,1
end_of_record
SF:lib/core/store.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/l10n/app_localizations.dart
DA:1,0
end_of_record
SF:lib/model.g.dart
DA:1,0
end_of_record
SF:lib/ui/page.dart
DA:1,0
end_of_record
''');
    final total = summarizeCoverage(files, (_) => true);
    expect(total.found, 3);
    expect(total.hit, 2);
    final core = summarizeCoverage(
      files,
      (path) => path.startsWith('lib/core/'),
    );
    expect(core.percent, 100);
  });

  // Тесты на трёх системах пропускают разное: реестр идёт только на
  // Windows, `.app` — только на macOS. Прежде покрытие снималось с одной
  // ubuntu, и такой тест можно было удалить — порог бы не заметил.
  test('отчёты систем сливаются: строка выполнена, если хоть одной', () {
    const ubuntu = '''
SF:lib/services/registry.dart
DA:1,1
DA:2,0
DA:3,0
end_of_record
''';
    const windows = r'''
SF:D:\a\evaporate\lib\services\registry.dart
DA:1,0
DA:2,4
DA:3,0
end_of_record
''';

    final merged = mergeCoverage([ubuntu, windows]);
    final registry = summarizeCoverage(merged, (_) => true);

    expect(merged.keys, ['lib/services/registry.dart']);
    expect(registry.found, 3, reason: 'строки не удваиваются');
    expect(registry.hit, 2);
  });

  test('слитый отчёт без одной из систем — не полная картина', () {
    expect(reportsProblem(systemCount, allSystems: true), isNull);
    expect(reportsProblem(systemCount - 1, allSystems: true), isNotNull);
    // Местный прогон — одна система, и полной картиной он не притворяется.
    expect(reportsProblem(1, allSystems: false), isNull);
  });

  test('пустой отчёт не считается полным покрытием', () {
    expect(summarizeCoverage(parseCoverage(''), (_) => true).percent, 0);
  });

  // Файл, не выполнявшийся ни разу, в отчёт не попадает вовсе — и потому
  // не снижает процент, а повышает его: чем меньше файл проверяли, тем
  // меньше у него строк в знаменателе. Такой обязан быть назван.
  test('файл без единой выполненной строки называется поимённо', () {
    final files = parseCoverage('''
SF:lib/core/store.dart
DA:1,1
end_of_record
''');

    expect(filesMissingFromReport(files, ['lib/core/store.dart']), isEmpty);
    expect(filesMissingFromReport(files, ['lib/services/тихий.dart']), [
      'lib/services/тихий.dart',
    ]);
  });

  test('названные причины молчания не считаются пропажей', () {
    expect(
      filesMissingFromReport(parseCoverage(''), ['lib/main.dart']),
      isEmpty,
    );
  });

  // Общий процент прячет нули: девятнадцать пустых файлов не двигали его и
  // на пункт. Поэтому храповик на файл.
  group('тонкие файлы', () {
    final files = parseCoverage('''
SF:lib/ui/new.dart
DA:1,1
DA:2,0
DA:3,0
end_of_record
SF:lib/ui/known.dart
DA:1,1
DA:2,0
DA:3,0
DA:4,0
end_of_record
SF:lib/ui/grown.dart
DA:1,1
DA:2,1
end_of_record
SF:lib/ui/solid.dart
DA:1,1
end_of_record
''');

    test('новый тонкий файл роняет прогон', () {
      expect(
        thinFileProblems(
          files,
          known: const {'lib/ui/known.dart': 25, 'lib/ui/grown.dart': 10},
        ),
        contains(startsWith('lib/ui/new.dart: 33%')),
      );
    });

    test('названный не может стать тоньше своего числа', () {
      final problems = thinFileProblems(
        files,
        known: const {'lib/ui/new.dart': 33, 'lib/ui/known.dart': 30},
      );
      expect(problems, [startsWith('lib/ui/known.dart: 25%')]);
    });

    test('доросший до порога обязан уйти из списка', () {
      final problems = thinFileProblems(
        files,
        known: const {
          'lib/ui/new.dart': 33,
          'lib/ui/known.dart': 25,
          'lib/ui/grown.dart': 10,
        },
      );
      expect(problems, [contains('вычеркните')]);
    });

    test('записи списка — настоящие файлы', () {
      // Переименованный файл иначе держал бы в списке место для нового.
      final sources = libSources().toSet();
      expect(thinFiles.keys.where((path) => !sources.contains(path)), isEmpty);
    });
  });

  test('в список файлов не попадают генерация и не-Dart', () {
    final sources = libSources();

    expect(sources, contains('lib/main.dart'));
    expect(sources, everyElement(endsWith('.dart')));
    expect(sources.where((path) => path.contains('/l10n/')), isEmpty);
  });
}
