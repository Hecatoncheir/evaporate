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
    final root = <String, Object>{};
    final stack = <Map<String, Object>>[root];
    // Ключ, у которого значением окажется следующий блок в фигурных скобках.
    String? pending;

    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//')) continue;

      if (line.startsWith('{')) {
        final key = pending;
        pending = null;
        if (key == null) continue;
        final child = <String, Object>{};
        stack.last[key] = child;
        stack.add(child);
        continue;
      }
      if (line.startsWith('}')) {
        pending = null;
        // Лишняя закрывающая скобка не должна опустошить корень.
        if (stack.length > 1) stack.removeLast();
        continue;
      }

      final tokens = _tokens(line);
      if (tokens.isEmpty) continue;
      if (tokens.length == 1) {
        pending = tokens.first;
      } else {
        pending = null;
        stack.last[tokens[0]] = tokens[1];
      }
    }
    return root;
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
        // Пути Windows записаны с удвоенными слешами: `C:\\Program Files`.
        buffer.write(char);
        escaped = false;
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
