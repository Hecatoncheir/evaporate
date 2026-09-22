import 'guards.dart';

/// Правки роли текста по месту не цветом: `context.text.caption.copyWith(
/// fontWeight: …)`. Роль правят только цветом — жирность, разрядка и
/// межстрочие по месту и есть то, от чего роли заводили.
///
/// Возвращает `путь: число` для файла с такими правками.
Iterable<String> roleTweaks(SourceFile file) sync* {
  final n = _calls(file.code, _roleCopy).where(_beyondColor).length;
  if (n > 0) yield '${file.path}: $n';
}

/// Стили текста, собранные по месту: `TextStyle(fontSize: …)`. Один цвет
/// стилем не считается — это «как вокруг, только другим цветом».
Iterable<String> inlineTextStyles(SourceFile file) sync* {
  final n = _calls(file.code, _textStyle).where(_beyondColor).length;
  if (n > 0) yield '${file.path}: $n';
}

/// `text.роль.copyWith(` — и через скобки выбора роли:
/// `(compact ? context.text.chip : context.text.caption).copyWith(`.
final _roleCopy = RegExp(r'\btext\.\w+\)?\s*\.copyWith\(');

/// `TextStyle(`, но не `DefaultTextStyle(`.
final _textStyle = RegExp(r'(?<![\w.])TextStyle\(');

bool _beyondColor(List<String> names) => names.any((name) => name != 'color');

/// Имена именованных аргументов каждого вызова, найденного [call].
Iterable<List<String>> _calls(String code, RegExp call) sync* {
  for (final match in call.allMatches(code)) {
    final args = _arguments(code, match.end - 1);
    if (args != null) yield [for (final arg in args) ?_name(arg)];
  }
}

/// Аргументы вызова, скобка которого стоит в [open], — по запятым
/// верхнего уровня, чтобы двоеточие тернарника в значении не сошло за
/// имя.
List<String>? _arguments(String code, int open) {
  final args = <String>[];
  var depth = 0;
  var start = open + 1;
  for (var k = open; k < code.length; k++) {
    final c = code[k];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (depth == 0) {
      args.add(code.substring(start, k));
      return args;
    }
    if (depth == 1 && c == ',') {
      args.add(code.substring(start, k));
      start = k + 1;
    }
  }
  return null;
}

String? _name(String argument) =>
    RegExp(r'^\s*(\w+)\s*:').firstMatch(argument)?.group(1);
