import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Имена и пути из документов существуют.
///
/// Документ — первое, что читают, прежде чем открыть код, и устаревшее имя
/// в нём уводит туда, где ничего нет: `lib/ui/app_colors.dart` в README
/// пережил переезд цветов в `lib/ui/theme/`, а «пять блоков» в CLAUDE.md —
/// появление ещё двух. Сверяется каждый путь и каждое CamelCase-имя в
/// обратных кавычках.
void main() {
  const documents = ['CLAUDE.md', 'README.md', 'CONTRIBUTING.md'];
  final code = _projectCode();

  for (final document in documents) {
    test('$document: пути и имена существуют', () {
      final text = File(document).readAsStringSync();
      expect(
        [
          for (final path in docPaths(text))
            if (!_exists(path)) 'путь $path',
          for (final name in docNames(text))
            if (!_formerNames.contains(name) &&
                !RegExp('\\b$name\\b').hasMatch(code))
              'имя $name',
        ],
        isEmpty,
        reason: 'поправьте документ или назовите исключение в _formerNames',
      );
    });
  }

  test('блоки уровня приложения — те, что раздаёт main.dart', () {
    final claude = File('CLAUDE.md').readAsStringSync();
    final sentence = RegExp(
      r'Блоков уровня приложения \S+ — их раздаёт `main\.dart`:([^.]*)\.',
    ).firstMatch(claude);
    expect(sentence, isNotNull, reason: 'фраза о блоках приложения пропала');
    final listed = docNames(sentence!.group(1)!).toSet();

    expect(listed, providedBlocs(File('lib/main.dart').readAsStringSync()));
  });

  group('страж ловит нарушение', () {
    test('пути и имена достаются из обратных кавычек', () {
      const text =
          'См. `lib/core/app_paths.dart`, `AppPaths.custom` и '
          '`flutter test`; `test/<раздел>/` — шаблон, а не путь.';
      expect(docPaths(text), ['lib/core/app_paths.dart']);
      expect(docNames(text), ['AppPaths']);
    });

    test('раздаваемые блоки видны и полем, и созданием на месте', () {
      const main = '''
class EvaporateApp extends StatefulWidget {
  final SettingsBloc settings;
  final DownloadsBloc downloads;
}
BlocProvider(create: (_) => NavigationBloc(library: widget.library)),
''';
      expect(providedBlocs(main), {
        'SettingsBloc',
        'DownloadsBloc',
        'NavigationBloc',
      });
    });
  });
}

/// Имена, которых в коде нет намеренно: документ рассказывает, чем они
/// стали.
const _formerNames = {'SaveFreshnessCubit'};

/// Пути от корня репозитория в обратных кавычках; шаблоны (`<…>`, `*`)
/// путями не считаются.
List<String> docPaths(String text) => [
  for (final match in RegExp(r'`([^`\n]+)`').allMatches(text))
    if (RegExp(
      r'^(?:lib|test|tool|windows|linux|macos|site|design|assets|third_party|\.github)/[\w./-]+$',
    ).hasMatch(match.group(1)!))
      match.group(1)!.replaceAll(RegExp(r'/$'), ''),
];

/// CamelCase-имена в обратных кавычках: `SnapshotStore`,
/// `AppPaths.custom` → `AppPaths`, `LibraryBloc(...)` → `LibraryBloc`.
List<String> docNames(String text) => [
  for (final match in RegExp(r'`([^`\n]+)`').allMatches(text))
    if (RegExp(r'^([A-Z][a-z0-9]+[A-Z]\w*)(?:\.\w+)*(?:\(.*\))?$')
            .firstMatch(match.group(1)!)
        case final name?)
      name.group(1)!,
];

/// Блоки, которые раздаёт `main.dart`: полями приложения и созданием на
/// месте в `BlocProvider`.
Set<String> providedBlocs(String main) => {
  for (final match in RegExp(r'final (\w+Bloc) \w+;').allMatches(main))
    match.group(1)!,
  for (final match in RegExp(
    r'BlocProvider\(\s*create:\s*\(_\)\s*=>\s*(\w+Bloc)\(',
  ).allMatches(main))
    match.group(1)!,
};

bool _exists(String path) =>
    File(path).existsSync() || Directory(path).existsSync();

/// Код проекта, где имена из документов обязаны найтись.
String _projectCode() {
  final buffer = StringBuffer();
  for (final root in ['lib', 'test', 'tool', '.github', 'windows', 'linux']) {
    if (!Directory(root).existsSync()) continue;
    for (final entity in Directory(root).listSync(recursive: true)) {
      // Фрагменты этого теста имена придумывают — искать среди них нельзя.
      if (entity is! File || entity.path.endsWith('docs_names_test.dart')) {
        continue;
      }
      if (!RegExp(r'\.(dart|ya?ml|sh|iss|py|arb|cmake|txt)$')
          .hasMatch(entity.path)) {
        continue;
      }
      buffer.writeln(entity.readAsStringSync());
    }
  }
  return buffer.toString();
}
