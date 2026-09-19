import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_complexity.dart';

/// Исходники Dart под [root], путями через `/` от корня репозитория —
/// так записи в списках стражей одинаковы на всех трёх системах.
List<SourceFile> dartSources(String root, {bool Function(String)? skip}) {
  final files = <SourceFile>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (skip?.call(path) ?? false) continue;
    files.add(SourceFile(path, entity.readAsStringSync()));
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

class SourceFile {
  SourceFile(this.path, this.text);

  final String path;
  final String text;

  /// Текст без комментариев и строковых литералов: страж ищет конструкции
  /// кода, а слово «isDark» в комментарии или «Widget» в строке — не они.
  /// Длина и переводы строк сохраняются, чтобы номера строк не съезжали.
  late final String code = stripCommentsAndStrings(text);
}

/// Храповик: найденное сверяется со списком известных нарушителей.
///
/// Новое нарушение роняет прогон — список нельзя пополнять, иначе правило
/// ничего не держит. Но и запись, которая перестала нарушать, обязана из
/// списка уйти: иначе на её место незаметно встало бы новое нарушение.
/// Так уборка идёт по частям, а новых нарушений не появляется с первого дня.
void expectRatchet({
  required Iterable<String> found,
  required Iterable<String> known,
  required String rule,
}) {
  final now = found.toSet();
  final allowed = known.toSet();
  final fresh = now.difference(allowed).toList()..sort();
  final stale = allowed.difference(now).toList()..sort();
  expect(
    fresh,
    isEmpty,
    reason: '$rule — новые нарушения:\n  ${fresh.join('\n  ')}',
  );
  expect(
    stale,
    isEmpty,
    reason:
        '$rule — эти записи больше не нарушают, вычеркните их из списка '
        'стража:\n  ${stale.join('\n  ')}',
  );
}
