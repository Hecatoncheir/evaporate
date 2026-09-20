import 'dart:io';

/// LCOV объединяется по файлу и номеру строки: повторные записи одного
/// исходника не должны искусственно увеличивать знаменатель.
Map<String, Map<int, int>> parseCoverage(String lcov) {
  final files = <String, Map<int, int>>{};
  String? current;
  for (final line in lcov.split('\n')) {
    if (line.startsWith('SF:')) {
      var path = line.substring(3).trim().replaceAll(r'\', '/');
      final lib = path.indexOf('/lib/');
      if (lib >= 0) path = path.substring(lib + 1);
      current =
          path.startsWith('lib/') &&
              !path.startsWith('lib/l10n/') &&
              !path.endsWith('.g.dart') &&
              !path.endsWith('.freezed.dart')
          ? path
          : null;
      if (current != null) files.putIfAbsent(current, () => {});
    } else if (line.startsWith('DA:') && current != null) {
      final values = line.substring(3).split(',');
      final number = int.parse(values[0]);
      final hits = int.parse(values[1]);
      final entries = files[current]!;
      entries[number] = (entries[number] ?? 0) + hits;
    } else if (line.trim() == 'end_of_record') {
      current = null;
    }
  }
  return files;
}

({int hit, int found, double percent}) summarizeCoverage(
  Map<String, Map<int, int>> files,
  bool Function(String path) includes,
) {
  var hit = 0;
  var found = 0;
  for (final file in files.entries) {
    if (!includes(file.key)) continue;
    found += file.value.length;
    hit += file.value.values.where((count) => count > 0).length;
  }
  return (hit: hit, found: found, percent: found == 0 ? 0 : 100 * hit / found);
}

/// Файлы `lib`, которых в отчёте нет вовсе.
///
/// Такой файл не «стопроцентный», а нулевой: он не выполнялся ни разу, и в
/// знаменатель покрытия не попал — то есть тем выше поднял процент, чем
/// меньше его проверяли. Отсюда отдельная проверка: непокрытый файл
/// обязан быть **назван**.
List<String> filesMissingFromReport(
  Map<String, Map<int, int>> files,
  Iterable<String> libFiles,
) => [
  for (final path in libFiles)
    if (!files.containsKey(path) && !_reportedNowhere.contains(path)) path,
]..sort();

/// Кого в отчёте нет и быть не должно.
///
/// Первые три — код, которого не бывает в тестах: `main` и сборка блоков
/// при запуске поднимают настоящее приложение, а системные уведомления —
/// обёртка над плагином, которому в прогоне отвечать некому. Остальные
/// три исполняемых строк не содержат вовсе: бочка экспортов,
/// перечислимая и таблица констант.
const _reportedNowhere = {
  'lib/main.dart',
  'lib/app_services.dart',
  'lib/services/notifications/system_notification_service.dart',
  'lib/ui/theme.dart',
  'lib/models/app_theme_mode.dart',
  'lib/ui/theme/alpha.dart',
};

/// Файлы `lib`, покрытие которых имеет смысл считать.
List<String> libSources([String root = 'lib']) => [
  for (final entity in Directory(root).listSync(recursive: true))
    if (entity is File && _measured(_asRepoPath(entity.path)))
      _asRepoPath(entity.path),
]..sort();

/// Путь от корня репозитория и через прямые косые: в отчёте они такие, а
/// на Windows `Directory.listSync` отдаёт обратные.
String _asRepoPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final lib = normalized.indexOf('lib/');
  return lib >= 0 ? normalized.substring(lib) : normalized;
}

bool _measured(String path) =>
    path.endsWith('.dart') &&
    !path.contains('/l10n/') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart');

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final files = parseCoverage(File(path).readAsStringSync());
  // Пороги стоят на два-три пункта ниже достигнутого, а не вровень с ним:
  // вплотную придвинутый порог валит прогон на любой мелочи — добавленной
  // ветке, новом файле чуть жиже остальных, — и кончается это тем, что его
  // опускают, то есть перестают им пользоваться. Запаса хватает на
  // обычные колебания и не хватает на настоящий откат.
  //
  // Растут они следом за покрытием: добрали — подняли. Иначе однажды
  // оказывается, что порог вдвое ниже того, что есть, и можно выкинуть
  // треть тестов, не заметив этого на прогоне.
  //
  // Сверяют их по прогону на ubuntu — по тому самому, где покрытие и
  // снимается. Там выполняется и то, что пропускается на Windows и macOS,
  // поэтому местный запуск на другой системе показывает меньше: у него
  // своя, неполная картина, и порог по ней был бы занижен.
  final scopes =
      <({String label, double minimum, bool Function(String) includes})>[
        (label: 'Весь код (без генерации)', minimum: 81, includes: (_) => true),
        (
          label: 'Ядро, модели и сервисы',
          minimum: 81,
          includes: (path) => [
            'lib/core/',
            'lib/models/',
            'lib/services/',
          ].any(path.startsWith),
        ),
        (
          label: 'Менеджер сохранений',
          minimum: 90,
          includes: (path) =>
              path == 'lib/services/saves/save_manager.dart' ||
              path == 'lib/services/saves/restore_transaction.dart',
        ),
      ];
  stdout.writeln('## Покрытие\n');
  for (final scope in scopes) {
    final result = summarizeCoverage(files, scope.includes);
    stdout.writeln(
      '- ${scope.label}: ${result.hit}/${result.found} '
      '(${result.percent.toStringAsFixed(1)}%), минимум ${scope.minimum}%.',
    );
    if (result.found == 0 || result.percent < scope.minimum) {
      stderr.writeln('Недостаточное покрытие: ${scope.label}');
      exitCode = 1;
    }
  }

  final missing = filesMissingFromReport(files, libSources());
  if (missing.isEmpty) return;
  stdout.writeln('\nНе выполнялись ни разу:');
  for (final path in missing) {
    stdout.writeln('- $path');
  }
  stderr.writeln(
    'Файлы без единой выполненной строки в отчёт не попадают и процент '
    'не снижают. Заведите им тест или назовите причину в _reportedNowhere.',
  );
  exitCode = 1;
}
