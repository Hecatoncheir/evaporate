import 'dart:io';

/// Замер длины, вложенности и когнитивной сложности функций — без
/// зависимостей, на разборе текста.
///
/// Разбор грубый и точным анализатором не притворяется: функции ищутся по
/// скобкам, ветвления — по ключевым словам. Для ранжирования «где болит» и
/// для храповика этого хватает, а `package:analyzer` в зависимостях — новая
/// тяжёлая зависимость, которая обсуждается отдельно.
///
/// Сложность считается по мотивам когнитивной сложности SonarSource:
///
/// - +1 за `if`, `else`, `for`, `while`, `do`, `switch`, `catch` и
///   тернарник, и ещё столько, на какой глубине вложенности они стоят;
/// - +1 за каждую смену логического оператора в выражении: `a && b && c` —
///   один, `a && b || c` — два.
///
/// Вложенность — наибольшая глубина фигурных скобок внутри тела: блоки
/// ветвлений, циклов и замыканий.
///
/// Запуск: `dart tool/check_complexity.dart [папка]` — выводит самые тяжёлые
/// функции. Ворота держит `test/guards/complexity_test.dart`.
void main(List<String> args) {
  final root = args.isEmpty ? 'lib' : args.first;
  final all = <FunctionMetrics>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (isGenerated(path)) continue;
    all.addAll(measure(path, entity.readAsStringSync()));
  }
  all.sort((a, b) => b.complexity.compareTo(a.complexity));
  stdout.writeln('сложн. строк влож.  функция');
  for (final f in all.take(40)) {
    stdout.writeln(
      '${'${f.complexity}'.padLeft(6)} '
      '${'${f.lines}'.padLeft(5)} '
      '${'${f.nesting}'.padLeft(5)}  ${f.path}: ${f.name}',
    );
  }
}

/// Сгенерированное в счёт не идёт: его никто не читает и не правит.
bool isGenerated(String path) =>
    path.contains('/l10n/app_localizations') ||
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart');

class FunctionMetrics {
  const FunctionMetrics({
    required this.path,
    required this.name,
    required this.line,
    required this.lines,
    required this.nesting,
    required this.complexity,
  });

  final String path;

  /// `Класс.метод` или имя функции верхнего уровня.
  final String name;
  final int line;
  final int lines;
  final int nesting;
  final int complexity;
}

/// Все функции файла с их показателями.
///
/// Вложенные функции и замыкания засчитываются той, в которой объявлены:
/// когнитивно это одна и та же функция, которую надо прочесть целиком.
List<FunctionMetrics> measure(String path, String source) {
  final code = stripCommentsAndStrings(source);
  final result = <FunctionMetrics>[];
  final names = <String, int>{};
  final classes = <({String name, int end})>[];

  var i = 0;
  while (i < code.length) {
    classes.removeWhere((c) => c.end <= i);

    final type = _typeHeader.matchAsPrefix(code, i);
    if (type != null && _startsWord(code, i)) {
      final open = code.indexOf('{', type.end - 1);
      final close = _matching(code, open);
      if (close != -1) {
        classes.add((name: type.group(1)!, end: close));
        i = open + 1;
        continue;
      }
    }

    final header = _functionAt(code, i);
    if (header != null) {
      final owner = classes.isEmpty ? '' : '${classes.last.name}.';
      var name = '$owner${header.name}';
      final seen = names[name] = (names[name] ?? 0) + 1;
      if (seen > 1) name = '$name#$seen';
      final body = code.substring(header.bodyStart, header.end);
      result.add(
        FunctionMetrics(
          path: path,
          name: name,
          line: _lineOf(code, header.start),
          lines: _lineOf(code, header.end) - _lineOf(code, header.start) + 1,
          nesting: _maxDepth(body),
          complexity: _complexity(body),
        ),
      );
      i = header.end;
      continue;
    }
    i++;
  }
  return result;
}

final _typeHeader = RegExp(
  r'(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*'
  r'(?:class|mixin|enum|extension(?:\s+type)?)\s+(\w*)[^{;]*\{',
);

const _notFunctions = {
  'if',
  'for',
  'while',
  'switch',
  'catch',
  'return',
  'assert',
  'super',
  'this',
  'await',
  'throw',
  'on',
  'when',
  'else',
};

/// Функция, которая начинается в позиции [i]: имя, скобки параметров и
/// тело — блоком или стрелкой.
({int start, String name, int bodyStart, int end})? _functionAt(
  String code,
  int i,
) {
  if (!_startsWord(code, i)) return null;
  final head = RegExp(
    r'(get\s+)?([A-Za-z_]\w*)\s*(?:<[^<>(){};=]*(?:<[^<>]*>[^<>(){};=]*)*>)?\s*',
  ).matchAsPrefix(code, i);
  if (head == null) return null;
  final name = head.group(2)!;
  if (_notFunctions.contains(name)) return null;
  final isGetter = head.group(1) != null;

  var j = head.end;
  if (!isGetter) {
    if (j >= code.length || code[j] != '(') return null;
    j = _matching(code, j);
    if (j == -1) return null;
    j++;
  }
  final tail = RegExp(r'\s*(?:async\*?|sync\*)?\s*(\{|=>)')
      .matchAsPrefix(code, j);
  if (tail == null) return null;
  // Перед именем должен стоять тип, модификатор или начало объявления, а
  // не выражение: иначе вызов `foo(a) {…}` не отличить от объявления. Вызов
  // с блоком после скобок в Dart не встречается, а вот `=>` бывает у
  // аргумента-замыкания — `map((x) => …)` — и его имя не предшествует.
  if (!_declarationContext(code, i)) return null;

  final bodyStart = tail.end;
  final int end;
  if (tail.group(1) == '{') {
    final close = _matching(code, tail.end - 1);
    if (close == -1) return null;
    end = close + 1;
  } else {
    end = _arrowEnd(code, tail.end);
  }
  return (start: i, name: name, bodyStart: bodyStart, end: end);
}

/// Перед объявлением стоит тип, модификатор, аннотация или граница
/// предыдущего члена, а не оператор выражения.
bool _declarationContext(String code, int i) {
  var k = i - 1;
  while (k >= 0 && (code[k] == ' ' || code[k] == '\t')) {
    k--;
  }
  if (k < 0) return true;
  final c = code[k];
  if (c == '\n' || c == ';' || c == '{' || c == '}') return true;
  // Тип возвращаемого значения: `Widget build(`, `List<Widget> _x(`,
  // `Future<void>? load(`.
  if (RegExp(r'[\w>?\]]').hasMatch(c)) {
    var start = k;
    while (start > 0 && _wordChar.hasMatch(code[start - 1])) {
      start--;
    }
    final previous = code.substring(start, k + 1);
    return previous.isEmpty ||
        !const {
          'return',
          'await',
          'throw',
          'else',
          'yield',
          'new',
          'const',
          'case',
          'in',
          'is',
          'as',
        }.contains(previous);
  }
  return false;
}

final _wordChar = RegExp(r'\w');

bool _startsWord(String code, int i) =>
    i == 0 || !RegExp(r'[\w$.]').hasMatch(code[i - 1]);

/// Парная скобка для `(`, `[` или `{` в позиции [open]; `-1`, если её нет.
int _matching(String code, int open) {
  const pairs = {'(': ')', '[': ']', '{': '}'};
  final stack = <String>[];
  for (var k = open; k < code.length; k++) {
    final c = code[k];
    if (pairs.containsKey(c)) {
      stack.add(pairs[c]!);
    } else if (stack.isNotEmpty && c == stack.last) {
      stack.removeLast();
      if (stack.isEmpty) return k;
    }
  }
  return -1;
}

/// Конец тела-стрелки: `;` или `,`/закрывающая скобка на нулевой глубине.
int _arrowEnd(String code, int from) {
  var depth = 0;
  for (var k = from; k < code.length; k++) {
    final c = code[k];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return k;
      depth--;
    }
    if (depth == 0 && c == ';') return k + 1;
  }
  return code.length;
}

int _lineOf(String code, int offset) =>
    '\n'.allMatches(code.substring(0, offset.clamp(0, code.length))).length + 1;

int _maxDepth(String body) {
  var depth = 0;
  var deepest = 0;
  for (var k = 0; k < body.length; k++) {
    if (body[k] == '{') {
      depth++;
      if (depth > deepest) deepest = depth;
    } else if (body[k] == '}') {
      depth--;
    }
  }
  // Собственные скобки тела-блока глубиной не считаются.
  return body.trimLeft().startsWith('{') ? deepest - 1 : deepest;
}

final _structure = RegExp(
  r'\b(else\s+if|if|else|for|while|do|switch|catch)\b|(\s\?\s)|(&&|\|\|)|([;{}])',
);

int _complexity(String body) {
  var score = 0;
  var depth = 0;
  String? lastLogical;
  var ownBrace = body.trimLeft().startsWith('{');
  for (final match in _structure.allMatches(body)) {
    final keyword = match.group(1);
    final ternary = match.group(2);
    final logical = match.group(3);
    final boundary = match.group(4);
    if (boundary != null) {
      lastLogical = null;
      if (boundary == '{') {
        if (ownBrace) {
          ownBrace = false;
        } else {
          depth++;
        }
      } else if (boundary == '}') {
        depth = depth > 0 ? depth - 1 : 0;
      }
      continue;
    }
    if (logical != null) {
      if (logical != lastLogical) score++;
      lastLogical = logical;
      continue;
    }
    if (ternary != null) {
      score += 1 + depth;
      continue;
    }
    // `else` и `else if` вложенностью не утяжеляются: это продолжение того
    // же ветвления, а не новое внутри него.
    if (keyword!.startsWith('else')) {
      score++;
    } else {
      score += 1 + depth;
    }
  }
  return score;
}

/// Заменяет комментарии и содержимое строк пробелами, не трогая переводы
/// строк, — чтобы ключевое слово в комментарии или скобка в строке не
/// сбивали разбор, а номера строк не съезжали. Сырые строки, тройные
/// кавычки учтены; строки внутри подстановок `${…}` — нет, и в этом коде
/// они на разбор не влияют.
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
      out
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
