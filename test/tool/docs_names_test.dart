import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Имена и пути из документов существуют.
///
/// Документ — первое, что читают, прежде чем открыть код, и устаревшее имя
/// в нём уводит туда, где ничего нет: `lib/ui/app_colors.dart` в README
/// пережил переезд цветов в `lib/ui/theme/`, а «пять блоков» в CLAUDE.md —
/// появление ещё двух. Сверяется каждый путь и каждое CamelCase-имя в
/// обратных кавычках, а также цель каждой ссылки внутрь репозитория:
/// `README.en.md` отсылал к `test/release_artifacts_test.dart` через месяц
/// после того, как тесты разложились по папкам.
void main() {
  // Записи решений — тоже: «почему нет X» уводит в пустоту, если Y, на
  // котором решение стоит, с тех пор переименовали. Оценки разборов —
  // нет: они описывают код своего дня. Отменённая запись — тоже нет, по
  // той же причине: её код убрала та запись, что её отменила.
  final documents = [
    'CLAUDE.md',
    'README.md',
    'README.en.md',
    'CONTRIBUTING.md',
    for (final entity in Directory(
      'docs/decisions',
    ).listSync()..sort((a, b) => a.path.compareTo(b.path)))
      if (entity is File &&
          entity.path.endsWith('.md') &&
          !isCancelled(entity.readAsStringSync()))
        entity.path.replaceAll(r'\', '/'),
  ];
  final code = _projectCode();

  for (final document in documents) {
    test('$document: пути и имена существуют', () {
      final text = File(document).readAsStringSync();
      expect(
        [
          for (final path in docPaths(text))
            if (!_exists(path)) 'путь $path',
          for (final link in docLinks(text))
            if (!_exists(_beside(document, link))) 'ссылка $link',
          for (final name in docNames(text))
            if (!_formerNames.contains(name) &&
                !_frameworkNames.contains(name) &&
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

    test('отменённую запись решения узнают по пометке', () {
      expect(
        isCancelled(
          '# 0007. X\n\n*Принято 2026-09-23.*\n\n'
          '*Отменено 2026-09-23 записью [0008](0008-y.md).*\n',
        ),
        isTrue,
      );
      // Слово в тексте — не пометка: отменить можно и что-то внутри
      // действующего решения.
      expect(isCancelled('# 0005. Z\n\nОтменено: прежний подход.\n'), isFalse);
    });

    test('ссылки внутрь репозитория — тоже пути', () {
      const text =
          '[тест](test/tool/gate_test.dart), [раздел](#ci), '
          '[сайт](https://example.org/a.dart), [код](lib/main.dart#L3)';
      expect(docLinks(text), ['test/tool/gate_test.dart', 'lib/main.dart']);
      expect(
        _beside('docs/decisions/README.md', '../reviews/a.md'),
        'docs/reviews/a.md',
      );
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

/// Запись решения, отменённая другой: строка-пометка `*Отменено …*` под
/// заголовком, как `*Принято …*`.
bool isCancelled(String record) =>
    RegExp(r'^\*Отменено ', multiLine: true).hasMatch(record);

/// Имена, которых в коде нет намеренно: документ рассказывает, чем они
/// стали, или почему их так и не завели.
const _formerNames = {
  'SaveFreshnessCubit',
  'DownloadHistoryCubit',
  'GameRepository',
  'ButtonCaptureBloc',
  'CaptureStarted',
  'RawButtonPressed',
  'CaptureCancelled',
  'WindowBloc',
};

/// Имена самого Flutter, которых в нашем коде нет, а в доводах они есть.
const _frameworkNames = {'AnimatedTheme'};

/// Пути от корня репозитория в обратных кавычках; шаблоны (`<…>`, `*`)
/// путями не считаются.
List<String> docPaths(String text) => [
  for (final match in RegExp(r'`([^`\n]+)`').allMatches(text))
    if (RegExp(
      r'^(?:lib|test|tool|windows|linux|macos|site|design|assets|third_party|\.github|\.githooks)/[\w./-]+$',
    ).hasMatch(match.group(1)!))
      match.group(1)!.replaceAll(RegExp(r'/$'), ''),
];

/// Цели ссылок внутрь репозитория — от папки самого документа, как их
/// читает GitHub; внешние адреса и якоря на своей странице мимо.
List<String> docLinks(String text) => [
  for (final match in RegExp(r'\]\(([^)#\s:]+)(?:#[^)]*)?\)').allMatches(text))
    match.group(1)!.replaceAll(RegExp(r'/$'), ''),
];

/// Путь ссылки [link] из документа [document] — от корня репозитория.
String _beside(String document, String link) {
  final parts = [...document.split('/')..removeLast(), ...link.split('/')];
  final resolved = <String>[];
  for (final part in parts) {
    if (part == '..') {
      resolved.removeLast();
    } else if (part != '.') {
      resolved.add(part);
    }
  }
  return resolved.join('/');
}

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
