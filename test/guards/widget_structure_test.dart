import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_complexity.dart';
import '../support/guards.dart';
import '../support/layering.dart';
import '../support/widget_structure.dart';

/// Порог длины замыкания-строителя в `build`.
const maxClosureLines = 25;

/// Один файл — один публичный виджет, и ни методов, собирающих виджеты.
///
/// Метод-виджет лишён своего `Element`: у него нет границы перестроения и
/// `const`, и в инспекторе его не видно. Приватный виджет — законная часть
/// своего единственного потребителя (`docs/decisions/0009`): у него всё
/// это есть, а лежит он там, где его и читают. Своим файлом ему быть, когда
/// он вырос, завёл ресурсы или понадобился второму. Законны и `_FooState` —
/// это идиома Flutter, а не виджет, — и `build`.
///
/// Виджеты живут не только в `lib/ui`: оболочка приложения — в
/// `lib/main.dart`, ввод (`InputScope`) — в `lib/input`. Прежде страж их не
/// обходил, и правило там держалось на честном слове.
///
/// Списки ниже — известные нарушители на момент введения правила (см.
/// этап 3 первого разбора, `docs/reviews/2026-09-19.md`). Пополнять их
/// нельзя; вынесенное — вычёркивать.
void main() {
  final sources = [
    ...dartSources('lib/ui', skip: isPrototypeCode),
    ...dartSources('lib/input'),
    SourceFile('lib/main.dart', File('lib/main.dart').readAsStringSync()),
  ];
  final types = widgetTypes(dartSources('lib'));

  test('приватный виджет — часть одного виджета, а не второй экран', () {
    expectRatchet(
      found: sources.expand((f) => privateWidgets(f, types: types)),
      known: _privateWidgets,
      rule:
          'вырос за $maxPrivateWidgetLines строк, завёл ресурсы или нужен '
          'второму — в свой файл под публичным именем',
    );
  });

  test('новых методов, собирающих виджеты, нет', () {
    expectRatchet(
      found: sources.expand((f) => widgetFunctions(f, types: types)),
      known: _widgetFunctions,
      rule: 'метод-виджет — в класс виджета своим файлом',
    );
  });

  // Число после двоеточия — сколько публичных виджетов в файле сейчас.
  // Вынесли один — число в списке уменьшается, вынесли все, кроме одного,
  // — запись уходит.
  test('новых файлов с несколькими публичными виджетами нет', () {
    expectRatchet(
      found: sources.expand((f) => crowdedFiles(f, types: types)),
      known: _crowdedFiles,
      rule: 'один файл — один публичный виджет',
    );
  });

  // Следующая ступень: то, чем дробление на виджеты обходят.
  test('замыкания-строители в build не длиннее $maxClosureLines строк', () {
    final longest = <String, int>{};
    for (final file in sources) {
      for (final c in buildClosures(file.path, file.text)) {
        if (c.lines <= maxClosureLines) continue;
        final key = '${file.path}: ${c.name}';
        if (c.lines > (longest[key] ?? 0)) longest[key] = c.lines;
      }
    }
    expectRatchet(
      found: [for (final e in longest.entries) '${e.key}: ${e.value}'],
      known: _longClosures,
      rule: 'длинное замыкание-строитель — в свой виджет',
    );
  });

  test('у виджета не больше семи параметров', () {
    expectRatchet(
      found: sources.expand((f) => wideWidgets(f, types: types)),
      known: _wideWidgets,
      rule: 'широкий виджет — на части или с одним значением вместо россыпи',
    );
  });

  // Папка обещает, что лежащее в ней нужно не одному месту: иначе читатель
  // ищет второе использование, которого нет, а виджет живёт вдали от
  // единственного экрана, который его читает.
  test('в lib/ui/widgets только нужное хотя бы двум местам', () {
    expectRatchet(
      found: lonelyShared(importGraph(dartSources('lib')), 'lib/ui/widgets'),
      known: _lonelyShared,
      rule:
          'нужное одному месту — к нему: в его файл (0009) или в его папку, '
          'если выросло, держит ресурсы или проверяется отдельно',
    );
  });

  // Сломанная регулярка — вечная зелень: страж, который ничего не
  // находит, выглядит ровно как страж, которому нечего найти.
  group('страж ловит нарушение', () {
    test('длинное замыкание-строитель в build', () {
      final lines = List.filled(maxClosureLines, '        const Text("x"),');
      final source =
          '''
class A extends StatelessWidget {
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Column(children: [
${lines.join('\n')}
        ]);
      },
    );
  }
}
''';
      final found = buildClosures('lib/ui/x.dart', source);
      expect(found.single.lines, greaterThan(maxClosureLines));
    });

    test('короткое замыкание и замыкание вне build не в счёт', () {
      const source = '''
class A extends StatelessWidget {
  void onTap() => items.forEach((x) { print(x); });
  Widget build(BuildContext context) =>
      ListView.builder(itemBuilder: (_, i) => Text('\$i'));
}
''';
      final found = buildClosures('lib/ui/x.dart', source);
      expect(found.map((c) => c.lines), [1]);
    });

    // Стрелка аргументом прежде тянулась до конца вызова и забирала
    // соседний `child` со всей разметкой: у `CoverBackdrop` «замыкание»
    // в одну строку выходило на тридцать две.
    test('стрелка-аргумент кончается запятой', () {
      final lines = List.filled(maxClosureLines, '        Text("x"),');
      final source =
          '''
class A extends StatelessWidget {
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (bounds) => gradient.createShader(bounds),
    child: Column(children: [
${lines.join('\n')}
    ]),
  );
}
''';
      expect(buildClosures('lib/ui/x.dart', source).map((c) => c.lines), [1]);
    });

    test('широкий виджет', () {
      final params = [for (var i = 0; i < 8; i++) 'required this.p$i'];
      final code = SourceFile('lib/ui/x.dart', '''
class Wide extends StatelessWidget {
  const Wide({super.key, ${params.join(', ')}});
}
class Narrow extends StatelessWidget {
  const Narrow(this.a, {super.key, required this.b, this.c = const []});
}
''');
      expect(wideWidgets(code), ['lib/ui/x.dart: Wide: 8']);
    });

    SourceFile file(String code) => SourceFile('lib/ui/x.dart', code);
    final types = widgetTypes([
      file('class SectionCard extends StatelessWidget {}'),
      file('class FancyCard extends SectionCard {}'),
    ]);

    const functions = {
      'метод с типом Widget': 'Widget _row() => const SizedBox();',
      'геттер-виджет': 'Widget get _header => const SizedBox();',
      'конкретный тип Flutter': 'Column _section() { return Column(); }',
      'список виджетов': 'List<Widget> _items() => [];',
      'статический метод': 'static Widget _make(BuildContext c) => Text("");',
      'свой виджет в возврате': 'FancyCard _card() => FancyCard();',
      'тип, допускающий null': 'Widget? _maybe() => null;',
    };
    for (final MapEntry(key: shape, value: code) in functions.entries) {
      test(shape, () {
        expect(widgetFunctions(file(code), types: types), hasLength(1));
      });
    }

    test('build, вызовы и поля нарушением не считаются', () {
      const code = '''
Widget build(BuildContext context) {
  return Column(children: [Text('a')]);
}
final Widget child;
''';
      expect(widgetFunctions(file(code), types: types), isEmpty);
    });

    // Приватный виджет законен у единственного потребителя; своим файлом
    // ему быть, когда он вырос, завёл ресурсы или понадобился второму.
    test('короткий приватный виджет у одного потребителя законен', () {
      final code = file('''
class A extends StatelessWidget {
  Widget build(BuildContext context) => const _Part();
}
class _Part extends FancyCard {
  const _Part();
}
''');
      expect(privateWidgets(code, types: types), isEmpty);
    });

    test('приватный наследник своего виджета длиннее порога', () {
      final body = List.filled(maxPrivateWidgetLines, '  final x = 0;');
      final code = file('''
class A extends StatelessWidget {
  Widget build(BuildContext context) => const _Long();
}
class _Long extends FancyCard {
${body.join('\n')}
}
''');
      expect(privateWidgets(code, types: types), [
        'lib/ui/x.dart: _Long: ${maxPrivateWidgetLines + 2} строк',
      ]);
    });

    test('приватный виджет со своим State, держащим ресурсы', () {
      final code = file('''
class A extends StatelessWidget {
  Widget build(BuildContext context) => const _Ticking();
}
class _Ticking extends StatefulWidget {
  State<_Ticking> createState() => _TickingState();
}
class _TickingState extends State<_Ticking> {
  final scroll = ScrollController();
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}
''');
      expect(privateWidgets(code, types: types), [
        'lib/ui/x.dart: _Ticking: State с ресурсами',
      ]);
    });

    test('приватный State без ресурсов законен', () {
      final code = file('''
class A extends StatelessWidget {
  Widget build(BuildContext context) => const _Toggle();
}
class _Toggle extends StatefulWidget {
  State<_Toggle> createState() => _ToggleState();
}
class _ToggleState extends State<_Toggle> {
  var on = false;
}
''');
      expect(privateWidgets(code, types: types), isEmpty);
    });

    test('приватный виджет, нужный двоим', () {
      final code = file('''
class A extends StatelessWidget {
  Widget build(BuildContext context) => const Row(children: [_Line(), _Mark()]);
}
class _Line extends StatelessWidget {
  Widget build(BuildContext context) => const _Mark();
}
class _Mark extends StatelessWidget {}
''');
      expect(privateWidgets(code, types: types), [
        'lib/ui/x.dart: _Mark: нужен A, _Line',
      ]);
    });

    test('поиск унаследованного виджета — не сборка', () {
      final code = file(
        'static WindowControl? maybeOf(BuildContext c) => c.dependOn();',
      );
      expect(widgetFunctions(code, types: {'WindowControl'}), isEmpty);
    });

    test('состояние виджетом не считается', () {
      final code = file('class _FooState extends State<Foo> {}');
      expect(privateWidgets(code, types: types), isEmpty);
    });

    test('два публичных виджета в файле', () {
      final code = file('''
class A extends StatelessWidget {}
class B extends FancyCard {}
''');
      expect(crowdedFiles(code, types: types), ['lib/ui/x.dart: 2']);
    });

    test('приватный виджет рядом с публичным файл не теснит', () {
      final code = file('''
class A extends StatelessWidget {}
class _B extends FancyCard {}
''');
      expect(crowdedFiles(code, types: types), isEmpty);
    });

    group('общая папка', () {
      final found = lonelyShared(
        importGraph([
          SourceFile(
            'lib/ui/a/page.dart',
            "import '../widgets/lone.dart';\n"
                "import '../widgets/shared.dart';",
          ),
          SourceFile('lib/ui/b/page.dart', "import '../widgets/shared.dart';"),
          SourceFile('lib/ui/widgets/shared.dart', "import 'part.dart';"),
          SourceFile('lib/ui/widgets/part.dart', ''),
          SourceFile('lib/ui/widgets/lone.dart', "import 'lone_part.dart';"),
          SourceFile('lib/ui/widgets/lone_part.dart', ''),
          SourceFile('lib/ui/widgets/unused.dart', ''),
        ]),
        'lib/ui/widgets',
      ).toList();

      test('файл, нужный одному месту', () {
        expect(
          found,
          contains('lib/ui/widgets/lone.dart -> lib/ui/a/page.dart'),
        );
      });

      test('часть виджета, которого целиком зовёт одно место', () {
        expect(
          found,
          contains('lib/ui/widgets/lone_part.dart -> lib/ui/a/page.dart'),
        );
      });

      test('файл, не нужный никому', () {
        expect(found, contains('lib/ui/widgets/unused.dart -> никто'));
      });

      test('нужное двоим и часть нужного двоим законны', () {
        expect(found, hasLength(3));
      });
    });
  });
}

const _privateWidgets = <String>[];

const _widgetFunctions = <String>[];

const _crowdedFiles = <String>[];

const _lonelyShared = <String>[];

/// Замыкания-строители в `build` длиннее 25 строк: `путь: build: длина
/// самого длинного`. Метод-виджет запрещён — и его обходят замыканием, те
/// же пятьдесят строк разметки без имени. Выросло число — новое нарушение;
/// укоротили — число правят следом.
const _longClosures = [
  'lib/ui/downloads/downloads_page.dart: DownloadsPage.build: 36',
  'lib/ui/downloads/queue_column.dart: QueueColumn.build: 38',
  'lib/ui/library/effects/library_atmosphere.dart: LibraryAtmosphereState.build: 40',
  'lib/ui/library/effects/portal/portal_sparks.dart: PortalSparksState.build: 30',
  'lib/ui/library/featured/shots_slideshow.dart: ShotsSlideshow.build: 40',
  'lib/ui/library/library_body.dart: LibraryBody.build: 28',
  'lib/ui/library/library_grid.dart: LibraryGrid.build: 30',
  'lib/ui/library/saves/restore_dialog.dart: _RestoreDialogState.build: 27',
  'lib/ui/window/interface_scale.dart: InterfaceScale.build: 28',
];

/// Виджеты больше чем с семью параметрами, кроме `key`: `путь: Имя: число`.
/// Родитель, передающий половину своего состояния по одной штуке, —
/// метод-виджет, переодетый классом.
const _wideWidgets = <String>[];
