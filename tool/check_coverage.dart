import 'dart:io';

/// Флаг: на входе отчёты всех систем прогона, и картина полная.
///
/// Тесты на трёх системах пропускают разное — реестр идёт только на
/// Windows, `.app` — только на macOS, меню приложений — только на Linux, —
/// и отчёт одной системы неполон. Храповик тонких файлов валит прогон
/// только на полной картине: на неполной файл выходит тоньше, чем он есть.
const allSystemsFlag = '--all-systems';

/// Сколько систем в матрице тестов CI — столько отчётов и ждём с
/// [allSystemsFlag].
const systemCount = 3;

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

/// Отчёты нескольких прогонов одним: строка выполнена, если её выполнил
/// хоть один. Прежде покрытие снималось с одной ubuntu, и тест, который
/// идёт только на Windows или macOS, можно было удалить — порог бы не
/// заметил.
Map<String, Map<int, int>> mergeCoverage(Iterable<String> reports) =>
    parseCoverage(reports.join('\n'));

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
/// обёртка над плагином, которому в прогоне отвечать некому. Выполняются
/// они всё же в каждой сборке: дымовой запуск (`--smoke`) поднимает и
/// гасит приложение целиком на трёх системах. Остальные
/// семь исполняемых строк не содержат вовсе: бочка экспортов,
/// перечислимая, четыре таблицы постоянных (прозрачности, ступени
/// отступов и значков, тайминги кадров) и интерфейс-метка частых событий.
const _reportedNowhere = {
  'lib/main.dart',
  'lib/app_services.dart',
  'lib/services/notifications/system_notification_service.dart',
  'lib/services/system/native_tray_host.dart',
  'lib/ui/theme.dart',
  'lib/models/app_theme_mode.dart',
  'lib/ui/theme/alpha.dart',
  'lib/ui/theme/icon_size.dart',
  'lib/ui/theme/spacing.dart',
  'lib/bloc/frequent_event.dart',
  'lib/ui/library/featured/shots_timing.dart',
};

/// Ниже какой доли файл считается почти непроверенным.
const thinBelow = 50;

/// Файлы, покрытые меньше чем на [thinBelow] процентов, и что с ними не так.
///
/// Общий процент прячет нули: девятнадцать файлов без единой выполненной
/// строки не сдвигали его и на пункт, потому что их строк — горсть на
/// тринадцать тысяч. Поэтому храповик на файл: новый тонкий файл роняет
/// прогон, названный не может стать тоньше своего числа, а добравший до
/// порога обязан из списка уйти — иначе на его место встал бы новый.
///
/// [known] — путь и доля в процентах, до которой файл может опуститься.
List<String> thinFileProblems(
  Map<String, Map<int, int>> files, {
  Map<String, int> known = thinFiles,
}) {
  final problems = <String>[];
  for (final MapEntry(key: path, value: lines) in files.entries) {
    if (lines.isEmpty) continue;
    final percent =
        100 * lines.values.where((c) => c > 0).length ~/ lines.length;
    final floor = known[path];
    if (floor == null && percent < thinBelow) {
      problems.add('$path: $percent% — новый файл почти без тестов');
    } else if (floor != null && percent < floor) {
      problems.add('$path: $percent% — было не меньше $floor%');
    } else if (floor != null && percent >= thinBelow) {
      problems.add('$path: $percent% — дорос до $thinBelow%, вычеркните');
    }
  }
  return problems..sort();
}

/// Файлы тоньше [thinBelow] процентов на момент введения правила. Число —
/// доля по слитому отчёту трёх систем (артефакт `coverage-<sha>`, три
/// `lcov.info`: `dart tool/check_coverage.dart --all-systems …`), **на три
/// пункта ниже достигнутой**: по тому же правилу, что и общие пороги, —
/// вровень придвинутое число валит прогон на любой мелочи. Пополнять
/// нельзя; добавили тестов — число поднимают, дорос до порога — запись
/// вычёркивают.
///
/// Файлы событий тонки по понятной причине: их `props` читает только
/// сравнение двух одинаковых событий, а его не бывает. Строки
/// `const`-конструкторов одни системы засчитывают выполненными, другие
/// нет, и какие — зависит от файла: у `proxy_form_event` их видит один
/// Windows, у `update_event` — все, кроме него. Отсюда у событий слитая
/// доля выше, чем по любой одной системе, и местный список им не судья.
const thinFiles = <String, int>{
  'lib/ui/downloads/engine_failure.dart': 0,
  'lib/ui/library/detail/cover_progress.dart': 0,
  'lib/ui/library/detail/executable_picker_dialog.dart': 0,
  'lib/ui/library/detail/game_error_note.dart': 0,
  'lib/ui/library/detail/running_game_actions.dart': 0,
  'lib/ui/library/saves/find_paths_progress.dart': 0,
  'lib/ui/saves/bulk_outcome_group.dart': 0,
  'lib/ui/saves/bulk_report_view.dart': 0,
  'lib/ui/saves/pick_game_dialog.dart': 0,
  'lib/ui/saves/sync_folder_contents.dart': 0,
  'lib/ui/saves/sync_package_row.dart': 0,
  'lib/ui/settings/pick_folder.dart': 0,
  'lib/ui/theme/theme_mode.dart': 0,
  'lib/ui/library/drop_overlay.dart': 2,
  'lib/ui/widgets/busy_spinner.dart': 17,
  'lib/bloc/library/library_event.dart': 21,
  'lib/ui/library/saves/snapshots_section.dart': 22,
  'lib/bloc/add_game/add_game_event.dart': 24,
  'lib/bloc/proxy_form/proxy_form_event.dart': 24,
  'lib/bloc/saves/saves_event.dart': 26,
  'lib/bloc/download_history/download_history_event.dart': 30,
  'lib/bloc/downloads/downloads_event.dart': 30,
  'lib/bloc/library_view/library_view_event.dart': 30,
  'lib/bloc/restore_preview/restore_preview_event.dart': 30,
  'lib/bloc/rule_form/rule_form_event.dart': 30,
  'lib/ui/settings/notification_actions.dart': 31,
  'lib/bloc/scan/scan_event.dart': 32,
  'lib/bloc/navigation/navigation_event.dart': 34,
  'lib/bloc/settings/settings_event.dart': 34,
  'lib/services/system/managed_window.dart': 35,
  'lib/services/download/engine_queue.dart': 41,
  'lib/ui/library/effects/cover_drops.dart': 44,
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

/// Что не так с набором отчётов, или `null`.
///
/// Полная картина, собранная не со всех систем, хуже неполной: храповик
/// тонких файлов судил бы по ней всерьёз. Пропавший отчёт системы должен
/// ронять прогон словами, а не тихо ослаблять правило.
String? reportsProblem(int count, {required bool allSystems}) {
  if (!allSystems || count == systemCount) return null;
  return 'С $allSystemsFlag ждём $systemCount отчёта — по одному с каждой '
      'системы, — а пришло $count.';
}

/// `dart tool/check_coverage.dart [--all-systems] [отчёт…]` — без отчётов
/// берётся `coverage/lcov.info` местного прогона.
void main(List<String> arguments) {
  final allSystems = arguments.contains(allSystemsFlag);
  final given = [
    for (final argument in arguments)
      if (argument != allSystemsFlag) argument,
  ];
  final reports = given.isEmpty ? const ['coverage/lcov.info'] : given;
  final problem = reportsProblem(reports.length, allSystems: allSystems);
  if (problem != null) {
    stderr.writeln(problem);
    exitCode = 1;
    return;
  }
  final files = mergeCoverage([
    for (final report in reports) File(report).readAsStringSync(),
  ]);
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
  // Сверяют их по слитому отчёту трёх систем — его проверяет задание
  // «Покрытие» в CI. Местный запуск на одной системе показывает меньше: у
  // него своя, неполная картина, и порог по ней был бы занижен.
  final scopes =
      <({String label, double minimum, bool Function(String) includes})>[
        (label: 'Весь код (без генерации)', minimum: 82, includes: (_) => true),
        (
          label: 'Ядро, модели и сервисы',
          minimum: 82,
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

  final thin = thinFileProblems(files);
  if (thin.isNotEmpty) {
    stdout.writeln('\nПочти без тестов (ниже $thinBelow%):');
    for (final problem in thin) {
      stdout.writeln('- $problem');
    }
    // Храповик на файл держит только слитый отчёт: в отчёте одной системы
    // пропущенные ею тесты делают файлы тоньше, а строка меню приложений,
    // которая бывает только на Linux, на Windows выходит нулём. Там список
    // показывается, но прогон не валит.
    if (allSystems) {
      stderr.writeln(
        'Тонкий файл: заведите ему тест или, если он дорос, уберите из '
        'thinFiles. Числа сверяют по слитому отчёту трёх систем.',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        '(отчёт одной системы — картина неполная, список не валит прогон; '
        'решает слитый отчёт трёх систем в CI)',
      );
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
