// Ворота CI одной командой: `dart tool/gate.dart`.
//
// Перечень шагов в CLAUDE.md держался памятью и отстал: локально гоняли три
// команды, а CI сверх них проверял `bloc lint`, регистраторы плагинов и порог
// покрытия — и красный прогон узнавали после пуша. Здесь шаги перечислены
// один раз, а `gate_test.dart` сверяет их с `ci.yml`: новый шаг CI без
// строчки здесь роняет прогон.
//
// Шаги идут по очереди и не обрываются на первом провале: список того, что
// сломано, полезнее одной первой причины. Итог — по коду возврата, как в CI.
import 'dart:convert';
import 'dart:io';

/// Один шаг ворот.
class GateStep {
  const GateStep(this.ciName, this.executable, this.arguments);

  /// Имя шага в `ci.yml` — по нему шаг сверяется с CI.
  final String ciName;
  final String executable;
  final List<String> arguments;

  String get command => [executable, ...arguments].join(' ');
}

/// Шаги в порядке CI. Тесты здесь в случайном порядке, как там: красный
/// `ca1356d` прошёл локально в порядке файлов.
const gateSteps = [
  GateStep('Форматирование', 'dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'lib',
    'test',
    'tool',
  ]),
  GateStep('Анализатор', 'flutter', ['analyze']),
  GateStep('Правила bloc', 'dart', [
    'pub',
    'global',
    'run',
    'bloc_tools:bloc',
    'lint',
    'lib',
  ]),
  GateStep('Регистраторы плагинов пересобраны', 'git', [
    'diff',
    '--exit-code',
    'linux',
    'windows',
    'macos',
  ]),
  GateStep('Тесты с покрытием', 'flutter', [
    'test',
    '--reporter',
    'failures-only',
    '--coverage',
    '--test-randomize-ordering-seed',
    'random',
  ]),
  GateStep('Порог покрытия без сгенерированного кода', 'dart', [
    'tool/check_coverage.dart',
  ]),
];

/// Шаги CI, которым здесь нечего делать: они про сам прогон — версию тега,
/// раздел CHANGELOG для него, выкладку артефактов, — а не про правку.
/// `Тесты` — тот же прогон на macOS и Windows: локально он уже есть как
/// `Тесты с покрытием`.
const ciOnlySteps = {
  'Версия',
  'Версия описана в CHANGELOG',
  'Приложить описание релиза',
  'Тесты',
  'Приложить отчёт о покрытии',
};

/// Версия Flutter, закреплённая в `ci.yml` (`env.FLUTTER_VERSION`).
String? pinnedFlutterVersion(String ciYaml) => RegExp(
  r'^\s*FLUTTER_VERSION:\s*(\S+)',
  multiLine: true,
).firstMatch(ciYaml)?.group(1);

/// Имена шагов задач `analyze` и `test` — тех, что гоняются на каждой
/// правке; сборки платформ локально не повторить.
List<String> ciCheckNames(String ciYaml) {
  final jobs = RegExp(
    r'^  analyze:$[\s\S]*?(?=^  build-)',
    multiLine: true,
  ).firstMatch(ciYaml);
  if (jobs == null) return const [];
  return [
    for (final m in RegExp(
      r'^\s+- name: (.+)$',
      multiLine: true,
    ).allMatches(jobs.group(0)!))
      m.group(1)!.trim(),
  ];
}

Future<String?> _localFlutterVersion() async {
  final result = await Process.run('flutter', [
    '--version',
    '--machine',
  ], runInShell: true);
  if (result.exitCode != 0) return null;
  final output = result.stdout as String;
  // Перед JSON Flutter иногда пишет предупреждения — берём с первой скобки.
  final start = output.indexOf('{');
  if (start < 0) return null;
  final json = jsonDecode(output.substring(start)) as Map<String, Object?>;
  return json['frameworkVersion'] as String?;
}

Future<void> _warnOnVersionDrift() async {
  final pinned = pinnedFlutterVersion(
    File('.github/workflows/ci.yml').readAsStringSync(),
  );
  final local = await _localFlutterVersion();
  if (pinned == null || local == null || pinned == local) return;
  // Предупреждение, а не провал: патч-версия обычно ничего не меняет, но
  // форматтер и анализатор между ними расходились — зелёное здесь не
  // обещает зелёного там.
  stdout.writeln('! Flutter $local, а CI закреплён на $pinned.');
}

Future<int> _run(GateStep step) async {
  stdout.writeln('\n== ${step.ciName}: ${step.command}');
  final process = await Process.start(
    step.executable,
    step.arguments,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<void> main() async {
  await _warnOnVersionDrift();
  final failed = <String>[];
  for (final step in gateSteps) {
    if (await _run(step) != 0) failed.add(step.ciName);
  }
  if (failed.isEmpty) {
    stdout.writeln('\nВорота пройдены.');
    return;
  }
  stderr.writeln('\nНе пройдено: ${failed.join(', ')}.');
  exitCode = 1;
}
