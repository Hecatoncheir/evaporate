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

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final files = parseCoverage(File(path).readAsStringSync());
  final scopes =
      <({String label, double minimum, bool Function(String) includes})>[
        (label: 'Весь код (без генерации)', minimum: 58, includes: (_) => true),
        (
          label: 'Ядро, модели и сервисы',
          minimum: 75,
          includes: (path) => [
            'lib/core/',
            'lib/models/',
            'lib/services/',
          ].any(path.startsWith),
        ),
        (
          label: 'Менеджер сохранений',
          minimum: 85,
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
}
