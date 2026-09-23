import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

/// Заменяет комментарии и содержимое строк пробелами, не трогая переводы
/// строк, — чтобы ключевое слово в комментарии или скобка в строке не
/// сбивали поиск, а номера строк не съезжали. Сырые строки и тройные
/// кавычки учтены; строки внутри подстановок `${…}` — нет, и в этом коде
/// они на поиск не влияют.
///
/// Стражам хватает текста: они ищут конструкции по образцу. Там, где нужен
/// разбор, — длина и сложность функций, — работает дерево
/// `package:analyzer` (`tool/check_complexity.dart`).
String stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  String blank(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');
  final quote = RegExp('(r?)(\'\'\'|"""|\'|")');
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      final stop = end == -1 ? source.length : end;
      out.write(blank(source.substring(i, stop)));
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? source.length : end + 2;
      out.write(blank(source.substring(i, stop)));
      i = stop;
      continue;
    }
    final match = quote.matchAsPrefix(source, i);
    if (match != null) {
      final raw = match.group(1)!.isNotEmpty;
      final delimiter = match.group(2)!;
      var j = match.end;
      while (j < source.length && !source.startsWith(delimiter, j)) {
        if (!raw && source[j] == r'\') j++;
        j++;
      }
      final contentEnd = j.clamp(0, source.length);
      // Приставку сырой строки — тоже: без неё разбор короче текста на
      // знак за каждую такую строку, и страж, сверяющий их по позициям,
      // смотрел мимо.
      out
        ..write(match.group(1))
        ..write(delimiter)
        ..write(blank(source.substring(match.end, contentEnd)))
        ..write(delimiter);
      i = (j + delimiter.length).clamp(0, source.length);
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
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
