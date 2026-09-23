import 'guards.dart';

/// Объявление класса с родителем: `class Foo<T> extends Bar`.
final _classWithParent = RegExp(
  r'^\s*(?:abstract\s+)?(?:final\s+)?(?:base\s+)?class\s+(\w+)(?:<[^>{]*>)?\s+extends\s+(\w+)\b',
  multiLine: true,
);

/// Объявление функции, метода или геттера с типом возврата: `Widget _row(`,
/// `Column get _header =>`, `static List<Widget> _items(`. Вызовы сюда не
/// попадают: перед именем обязан стоять тип.
final _typedDeclaration = RegExp(
  r'^\s*(?:static\s+)?(\w+)(?:<\s*(\w+)\s*>)?\??\s+(get\s+)?(\w+)\s*(?:<[^>(]*>)?\s*(\(|=>|\{)',
  multiLine: true,
);

/// Частые виджеты Flutter, которыми метод-виджет бывает объявлен вместо
/// `Widget`: `Column _section()` — тот же метод-виджет, и страж, знавший
/// только `Widget`, его не видел.
const flutterWidgets = {
  'Widget',
  'PreferredSizeWidget',
  'Align',
  'AlertDialog',
  'AnimatedBuilder',
  'Builder',
  'Card',
  'Center',
  'Column',
  'Container',
  'DecoratedBox',
  'Divider',
  'Expanded',
  'Flexible',
  'GestureDetector',
  'Icon',
  'IconButton',
  'InkWell',
  'ListTile',
  'ListView',
  'Padding',
  'Positioned',
  'Row',
  'Scaffold',
  'SizedBox',
  'Stack',
  'Text',
  'Tooltip',
  'Wrap',
};

/// Типы виджетов, известные по [files]: частые из Flutter, всё на
/// `…Widget` и свои классы, наследующие любой из них — `class Foo extends
/// SectionCard` такой же виджет, хотя в имени родителя `Widget` нет.
Set<String> widgetTypes(Iterable<SourceFile> files) {
  final types = {...flutterWidgets};
  final parents = {
    for (final file in files)
      for (final match in _classWithParent.allMatches(file.code))
        match.group(1)!: match.group(2)!,
  };
  var grew = true;
  while (grew) {
    grew = false;
    for (final MapEntry(key: name, value: parent) in parents.entries) {
      if (types.contains(name)) continue;
      if (types.contains(parent) || parent.endsWith('Widget')) {
        types.add(name);
        grew = true;
      }
    }
  }
  return types;
}

/// Классы-виджеты файла.
Iterable<String> _widgetsIn(SourceFile file, Set<String> types) sync* {
  for (final match in _classWithParent.allMatches(file.code)) {
    final parent = match.group(2)!;
    if (types.contains(parent) || parent.endsWith('Widget')) {
      yield match.group(1)!;
    }
  }
}

/// Порог длины приватного виджета — класса целиком, от `class` до
/// закрывающей скобки.
const maxPrivateWidgetLines = 40;

/// Приватные виджеты, которым больше не место в файле потребителя:
/// длиннее [maxLines] строк, со своим `State`, держащим ресурсы, или
/// нужные двум и больше классам файла.
///
/// Сам приватный виджет законен (`docs/decisions/0009`): у него есть свой
/// `Element`, `const` и граница перестроения, а лежит он там же, где его
/// единственный потребитель. Своим файлом ему быть, когда он перестаёт быть
/// частью одного виджета.
Iterable<String> privateWidgets(
  SourceFile file, {
  Set<String> types = flutterWidgets,
  int maxLines = maxPrivateWidgetLines,
}) sync* {
  final spans = _classSpans(file.code);
  for (final name in _widgetsIn(file, types)) {
    final span = spans[name];
    if (!name.startsWith('_') || span == null) continue;
    final lines = '\n'.allMatches(file.code.substring(span.start, span.end));
    if (lines.length + 1 > maxLines) {
      yield '${file.path}: $name: ${lines.length + 1} строк';
      continue;
    }
    final state = _stateOf(name, file.code);
    final stateSpan = state == null ? null : spans[state];
    if (stateSpan != null && _disposes(file.code, stateSpan)) {
      yield '${file.path}: $name: State с ресурсами';
      continue;
    }
    final users = _usersOf(name, file.code, spans, own: {name, ?state});
    if (users.length > 1) {
      yield '${file.path}: $name: нужен ${users.join(', ')}';
    }
  }
}

typedef _Span = ({int start, int end});

/// Где в разборе лежит каждый класс: от слова `class` до закрывающей
/// скобки. Строки и комментарии в разборе затёрты, и скобка внутри них
/// счёт не собьёт.
Map<String, _Span> _classSpans(String code) {
  final spans = <String, _Span>{};
  for (final match in _classHead.allMatches(code)) {
    final open = code.indexOf('{', match.end);
    if (open < 0) continue;
    var depth = 0;
    var end = open;
    for (; end < code.length; end++) {
      if (code[end] == '{') depth++;
      if (code[end] == '}' && --depth == 0) break;
    }
    spans[match.group(2)!] = (
      start: match.start + match.group(1)!.length,
      end: end,
    );
  }
  return spans;
}

final _classHead = RegExp(
  r'^(\s*(?:abstract\s+)?(?:final\s+)?(?:base\s+)?)class\s+(\w+)',
  multiLine: true,
);

/// Класс состояния виджета [widget], если он есть: `extends State<_Foo>`.
String? _stateOf(String widget, String code) => RegExp(
  'class\\s+(\\w+)[^{]*?\\bextends\\s+State<\\s*${RegExp.escape(widget)}\\s*>',
).firstMatch(code)?.group(1);

/// Держит ли класс ресурсы — то, что освобождают в `dispose`.
bool _disposes(String code, _Span span) =>
    RegExp(r'\bdispose\s*\(').hasMatch(code.substring(span.start, span.end));

/// Классы файла, которые пользуются [name], — кроме [own]: сам виджет и его
/// состояние. Упоминание вне всякого класса считается отдельным
/// потребителем.
List<String> _usersOf(
  String name,
  String code,
  Map<String, _Span> spans, {
  required Set<String> own,
}) {
  final users = <String>{};
  for (final match in RegExp('\\b${RegExp.escape(name)}\\b').allMatches(code)) {
    final holder = spans.entries
        .where(
          (e) => e.value.start <= match.start && match.start <= e.value.end,
        )
        .map((e) => e.key)
        .firstOrNull;
    if (holder != null && own.contains(holder)) continue;
    users.add(holder ?? 'верхний уровень');
  }
  return users.toList()..sort();
}

/// Функции, методы и геттеры, собирающие виджеты, — кроме `build`: он и
/// есть законное место сборки. Метод-виджет — тот же приватный виджет,
/// только без своего `Element`: без границы перестроения, без `const`,
/// невидимый в инспекторе.
Iterable<String> widgetFunctions(
  SourceFile file, {
  Set<String> types = flutterWidgets,
}) sync* {
  for (final match in _typedDeclaration.allMatches(file.code)) {
    final type = match.group(1)!;
    final element = match.group(2);
    final isWidget = element == null
        ? types.contains(type) || type.endsWith('Widget')
        : type == 'List' && types.contains(element);
    final name = match.group(4)!;
    // `of` и `maybeOf` у `InheritedWidget` виджет ищут, а не собирают:
    // это идиома Flutter, а не метод-виджет.
    if (!isWidget || const {'build', 'of', 'maybeOf'}.contains(name)) {
      continue;
    }
    // `class Foo extends …` сюда не попадает: у объявления класса нет ни
    // скобок, ни стрелки сразу за именем.
    yield '${file.path}: $name';
  }
}

/// Виджеты с числом параметров конструктора больше [limit], кроме `key`:
/// `путь: Имя: число`.
///
/// Дробление на виджеты обходят и так: восемь, десять, четырнадцать
/// параметров — это метод-виджет, переодетый классом, в который родитель
/// передаёт половину своего состояния по одной штуке.
Iterable<String> wideWidgets(
  SourceFile file, {
  Set<String> types = flutterWidgets,
  int limit = 7,
}) sync* {
  for (final name in _widgetsIn(file, types)) {
    final ctor = RegExp('(?:const\\s+)?\\b$name\\s*\\(')
        .firstMatch(file.code.substring(file.code.indexOf('class $name')));
    if (ctor == null) continue;
    final start = file.code.indexOf('class $name') + ctor.end;
    var depth = 1;
    var end = start;
    for (; end < file.code.length && depth > 0; end++) {
      final c = file.code[end];
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) depth--;
    }
    final params = _topLevelParts(file.code.substring(start, end - 1))
        .where((part) => part.isNotEmpty && !part.contains('key'))
        .length;
    if (params > limit) yield '${file.path}: $name: $params';
  }
}

/// Части списка параметров, разделённые запятыми на верхнем уровне.
///
/// Глубина — только по круглым и угловым скобкам: фигурные и квадратные
/// на верхнем уровне — рамки именованных и необязательных параметров, и
/// запятые внутри них делят параметры так же.
List<String> _topLevelParts(String params) {
  final parts = <String>[];
  var depth = 0;
  var from = 0;
  for (var k = 0; k < params.length; k++) {
    final c = params[k];
    if (c == '(' || c == '<') depth++;
    if (c == ')' || c == '>') depth--;
    if (c == ',' && depth == 0) {
      parts.add(params.substring(from, k));
      from = k + 1;
    }
  }
  parts.add(params.substring(from));
  return [
    for (final part in parts) part.replaceAll(RegExp(r'[{}\[\]]'), '').trim(),
  ];
}

/// Файл, где объявлено больше одного публичного виджета. Приватные — часть
/// своего потребителя (`docs/decisions/0009`) и файла не теснят.
Iterable<String> crowdedFiles(
  SourceFile file, {
  Set<String> types = flutterWidgets,
}) sync* {
  final count = _widgetsIn(
    file,
    types,
  ).where((name) => !name.startsWith('_')).length;
  if (count > 1) yield '${file.path}: $count';
}

/// Файлы общей папки [folder], нужные меньше чем двум местам вне неё:
/// `путь -> единственное место` или `путь -> никто`.
///
/// Места считаются за папкой: файл, нужный лишь соседу по ней, служит тем
/// же, кому служит сосед. Так краска и геометрия переиспользуемого виджета
/// законны, пока нужен он сам, а цепочка, которую целиком зовёт одно
/// место, — нет. [graph] — импорты `lib` (`importGraph`): тест потребителем
/// не считается, он проверяет, а не пользуется.
Iterable<String> lonelyShared(
  Map<String, List<String>> graph,
  String folder,
) sync* {
  final importers = <String, Set<String>>{};
  for (final MapEntry(key: file, value: targets) in graph.entries) {
    for (final target in targets) {
      (importers[target] ??= {}).add(file);
    }
  }
  bool inside(String path) => path.startsWith('$folder/');

  Set<String> usersOf(String file) {
    final users = <String>{};
    final queue = [file];
    final seen = {file};
    while (queue.isNotEmpty) {
      for (final user in importers[queue.removeLast()] ?? const <String>{}) {
        if (!seen.add(user)) continue;
        if (inside(user)) {
          queue.add(user);
        } else {
          users.add(user);
        }
      }
    }
    return users;
  }

  for (final file in graph.keys.where(inside)) {
    final users = usersOf(file);
    if (users.length < 2) {
      yield '$file -> ${users.isEmpty ? 'никто' : users.single}';
    }
  }
}
