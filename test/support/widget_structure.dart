import 'guards.dart';

/// Класс, наследующий какой-либо `…Widget`: `StatelessWidget`,
/// `StatefulWidget`, `InheritedWidget`, `ImplicitlyAnimatedWidget`,
/// `SingleChildRenderObjectWidget` и прочие. `State<…>` сюда не попадает.
final _widgetClass = RegExp(
  r'^\s*(?:abstract\s+)?(?:final\s+)?class\s+(\w+)(?:<[^>{]*>)?\s+extends\s+(\w*Widget)\b',
  multiLine: true,
);

/// Объявление функции или метода, возвращающего виджет: `Widget _row(`,
/// `List<Widget> _items(`, `static Widget of(`. Вызовы сюда не попадают:
/// перед именем обязан стоять тип.
final _widgetFunction = RegExp(
  r'^\s*(?:static\s+)?(?:Widget|PreferredSizeWidget|List<Widget>)\??\s+(\w+)\s*(?:<[^>(]*>)?\(',
  multiLine: true,
);

/// Приватные виджеты: `class _Foo extends StatelessWidget`.
Iterable<String> privateWidgets(SourceFile file) sync* {
  for (final match in _widgetClass.allMatches(file.code)) {
    final name = match.group(1)!;
    if (name.startsWith('_')) yield '${file.path}: $name';
  }
}

/// Функции и методы, собирающие виджеты, — кроме `build`: он и есть
/// законное место сборки. Метод-виджет — тот же приватный виджет, только
/// без своего `Element`: без границы перестроения, без `const`, невидимый
/// в инспекторе.
Iterable<String> widgetFunctions(SourceFile file) sync* {
  for (final match in _widgetFunction.allMatches(file.code)) {
    final name = match.group(1)!;
    if (name == 'build') continue;
    yield '${file.path}: $name';
  }
}

/// Файл, где объявлено больше одного виджета.
Iterable<String> crowdedFiles(SourceFile file) sync* {
  final count = _widgetClass.allMatches(file.code).length;
  if (count > 1) yield '${file.path}: $count';
}
