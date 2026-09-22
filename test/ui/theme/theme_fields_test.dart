import 'package:flutter_test/flutter_test.dart';

import '../../support/guards.dart';

/// Расширение темы не теряет поле при смене схемы — проверка по исходнику.
///
/// Тест по значениям (`lerp(…).values == values`) ловит поле, забытое в
/// `lerp`, только если оно есть в `values`; поле, забытое и там и там, он
/// пропускал — ровно тот случай, ради которого написан. Поэтому счёт
/// ведётся от объявлений: сколько у класса `final`-полей, столько
/// именованных аргументов у конструктора, который собирает `lerp`, и
/// столько элементов в `values`, если он есть.
void main() {
  final extensions = [
    for (final file in dartSources('lib/ui/theme')) ...themeExtensions(file),
  ];

  test('расширения темы нашлись', () {
    // Иначе проверка ниже прошла бы на пустом списке.
    expect(
      extensions.map((e) => e.name),
      containsAll([
        'EvaporatePalette',
        'HardwareSurfaceTheme',
        'EffectsPalette',
        'EvaporateMotion',
      ]),
    );
  });

  for (final extension in extensions) {
    test('${extension.name}: lerp смешивает каждое поле', () {
      expect(extension.lerpArguments, unorderedEquals(extension.fields));
    });

    if (extension.values != null) {
      test('${extension.name}: values перечисляет каждое поле', () {
        expect(extension.values, extension.fields.length);
      });
    }
  }

  group('страж ловит нарушение', () {
    test('поле, забытое в lerp', () {
      final found = themeExtensions(
        SourceFile('lib/ui/theme/x.dart', '''
class Look extends ThemeExtension<Look> {
  const Look({required this.a, required this.b});
  final Color a;
  final Color b;
  @override
  Look lerp(ThemeExtension<Look>? other, double t) {
    if (other is! Look) return this;
    return Look(a: Color.lerp(a, other.a, t)!);
  }
}
'''),
      ).single;
      expect(found.fields, ['a', 'b']);
      expect(found.lerpArguments, ['a']);
    });
  });
}

/// Что известно о расширении темы по его исходнику.
typedef ThemeExtensionShape = ({
  String name,
  List<String> fields,
  List<String> lerpArguments,
  int? values,
});

/// Расширения темы файла: поля, аргументы конструктора в `lerp` и длина
/// `values`.
Iterable<ThemeExtensionShape> themeExtensions(SourceFile file) sync* {
  final code = file.code;
  final header = RegExp(r'class\s+(\w+)\s+extends\s+ThemeExtension<');
  for (final match in header.allMatches(code)) {
    final name = match.group(1)!;
    final open = code.indexOf('{', match.end);
    final body = code.substring(open + 1, _closing(code, open));
    final fields = [
      for (final field in RegExp(
        r'^  final\s+[\w<>?, ]+\s+(\w+)\s*;',
        multiLine: true,
      ).allMatches(body))
        field.group(1)!,
    ];
    yield (
      name: name,
      fields: fields,
      lerpArguments: _lerpArguments(body, name),
      values: _valuesLength(body),
    );
  }
}

/// Именованные аргументы конструктора, которым `lerp` собирает результат.
List<String> _lerpArguments(String body, String name) {
  final lerp = RegExp(r'\blerp\s*\(').firstMatch(body);
  if (lerp == null) return const [];
  final call = body.indexOf('$name(', lerp.end);
  if (call < 0) return const [];
  final open = call + name.length;
  return _topLevelNames(body.substring(open + 1, _closing(body, open)));
}

/// Длина списка в `get values => [ … ]`, если геттер есть.
int? _valuesLength(String body) {
  final values = RegExp(r'get\s+values\s*=>\s*\[').firstMatch(body);
  if (values == null) return null;
  final open = values.end - 1;
  final inner = body.substring(open + 1, _closing(body, open));
  return _topLevelParts(inner).where((p) => p.trim().isNotEmpty).length;
}

List<String> _topLevelNames(String args) => [
  for (final part in _topLevelParts(args))
    if (RegExp(r'^\s*(\w+)\s*:').firstMatch(part) case final m?) m.group(1)!,
];

List<String> _topLevelParts(String text) {
  final parts = <String>[];
  var depth = 0;
  var from = 0;
  for (var k = 0; k < text.length; k++) {
    final c = text[k];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      parts.add(text.substring(from, k));
      from = k + 1;
    }
  }
  parts.add(text.substring(from));
  return parts;
}

/// Парная закрывающая скобка для открывающей в [open].
int _closing(String code, int open) {
  var depth = 0;
  for (var k = open; k < code.length; k++) {
    if ('([{'.contains(code[k])) depth++;
    if (')]}'.contains(code[k]) && --depth == 0) return k;
  }
  return code.length;
}
