/// Разбор текстового формата Valve (VDF/ACF).
///
/// В нём Steam держит на диске то, что приложению иначе приходится
/// угадывать: список библиотек и точные сведения о каждой установленной
/// игре. Формат простой — вложенные блоки из строк `"ключ" "значение"`, —
/// и ради него тащить зависимость незачем.
///
/// ```
/// "AppState"
/// {
///   "appid"    "478980"
///   "name"     "Mansions of Madness"
/// }
/// ```
class Vdf {
  const Vdf._();

  /// Разбирает документ в дерево карт.
  ///
  /// Значения — либо `String`, либо вложенная `Map<String, Object>`.
  /// Ключ, встретившийся дважды, оставляет последнее значение: так же
  /// поступает и сам Steam.
  ///
  /// Возвращает пустую карту на непонятном тексте, а не бросает: файл
  /// принадлежит чужой программе, его формат может поменяться, и падать
  /// из-за этого приложению незачем.
  static Map<String, Object> parse(String source) {
    final document = _VdfDocument();
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//')) continue;

      if (line.startsWith('{')) {
        document.open();
      } else if (line.startsWith('}')) {
        document.close();
      } else {
        document.line(_tokens(line));
      }
    }
    return document.root;
  }

  /// Строки в кавычках из одной строки файла.
  ///
  /// Разделителем служат табуляции и пробелы, но полагаться на них нельзя:
  /// в значениях они встречаются («Mansions of Madness»). Поэтому читаем по
  /// кавычкам, а не режем по пробелам.
  static List<String> _tokens(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inside = false;
    var escaped = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (escaped) {
        escaped = false;
        buffer.write(_unescape(char));
        continue;
      }
      if (char == r'\' && inside) {
        escaped = true;
        continue;
      }
      if (char == '"') {
        if (inside) {
          result.add(buffer.toString());
          buffer.clear();
        }
        inside = !inside;
        continue;
      }
      if (inside) buffer.write(char);
    }
    return result;
  }

  /// Знак после обратного слеша.
  ///
  /// Valve знает `\\`, `\"`, `\n` и `\t`. Всё прочее возвращается как есть,
  /// вместе со слешем: файл чужой, и проглотить в нём слеш молча значит
  /// испортить путь, ничего об этом не сказав.
  static String _unescape(String char) => switch (char) {
    r'\' || '"' => char,
    'n' => '\n',
    't' => '\t',
    _ => '\\$char',
  };

  /// Значение по цепочке ключей: `Vdf.string(doc, ['AppState', 'name'])`.
  static String? string(Map<String, Object> doc, List<String> path) {
    Object? current = doc;
    for (final key in path) {
      if (current is! Map<String, Object>) return null;
      current = current[key];
    }
    return current is String ? current : null;
  }

  /// Вложенная карта по цепочке ключей.
  static Map<String, Object>? map(Map<String, Object> doc, List<String> path) {
    Object? current = doc;
    for (final key in path) {
      if (current is! Map<String, Object>) return null;
      current = current[key];
    }
    return current is Map<String, Object> ? current : null;
  }
}

/// Дерево разбираемого документа и место, где разбор сейчас находится.
///
/// Стек и «ключ, ждущий блока» жили внутри самого разбора, и из-за них он
/// читался как три дела сразу: где мы, что кладём и чем считать строку.
class _VdfDocument {
  final root = <String, Object>{};
  late final List<Map<String, Object>> _stack = [root];

  /// Ключ, у которого значением окажется следующий блок в скобках.
  String? _pending;

  /// Открылся блок: он и есть значение ключа из прошлой строки.
  void open() {
    final key = _pending;
    _pending = null;
    if (key == null) return;
    final child = <String, Object>{};
    _stack.last[key] = child;
    _stack.add(child);
  }

  void close() {
    _pending = null;
    // Лишняя закрывающая скобка не должна опустошить корень.
    if (_stack.length > 1) _stack.removeLast();
  }

  /// Строка со значениями: одна строка в кавычках — ключ будущего блока,
  /// две — готовая пара.
  void line(List<String> tokens) {
    if (tokens.isEmpty) return;
    if (tokens.length == 1) {
      _pending = tokens.first;
      return;
    }
    _pending = null;
    _stack.last[tokens[0]] = tokens[1];
  }
}
