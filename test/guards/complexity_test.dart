import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_complexity.dart';
import '../support/guards.dart';

/// Функции остаются короткими, неглубокими и читаемыми с одного прохода.
///
/// Пороги — сложность 15, длина 60 строк, вложенность 3. Их, как и порог
/// покрытия, держат следом за достигнутым: убрали тяжёлые функции —
/// порог опускают, иначе он перестаёт ловить хоть что-то.
///
/// Списки ниже — известные нарушители со своим числом на момент введения
/// правила (этап 5 в `TODO.md`). Выросло число — это новое нарушение;
/// уменьшилось — число в списке правят вслед; опустилось до порога —
/// запись вычёркивают.
const maxComplexity = 15;
const maxLines = 60;
const maxNesting = 3;

void main() {
  final functions = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        if (entity.path.replaceAll(r'\', '/') case final path
            when !isGenerated(path))
          ...measure(path, entity.readAsStringSync()),
  ];

  Iterable<String> over(int Function(FunctionMetrics) metric, int limit) sync* {
    for (final f in functions) {
      final value = metric(f);
      if (value > limit) yield '${f.path}: ${f.name}: $value';
    }
  }

  group('ворота', () {
    test('сложность функций не выше $maxComplexity', () {
      expectRatchet(
        found: over((f) => f.complexity, maxComplexity),
        known: _complexity,
        rule: 'разложите ветвления: ранний выход, таблица, именованные шаги',
      );
    });

    test('функции не длиннее $maxLines строк', () {
      expectRatchet(
        found: over((f) => f.lines, maxLines),
        known: _lines,
        rule: 'длинную функцию — на шаги, длинный build — на виджеты',
      );
    });

    test('вложенность не глубже $maxNesting', () {
      expectRatchet(
        found: over((f) => f.nesting, maxNesting),
        known: _nesting,
        rule: 'глубокую вложенность — ранним выходом или своей функцией',
      );
    });
  });

  // Замер ищет функции по заголовку, перепись — по телу. Разошлись —
  // значит, какую-то функцию замер не узнал, и её длина со сложностью
  // идут мимо ворот. Так незамеченными ходили конструктор `LibraryBloc`
  // на девяносто пять строк, все фабрики `fromJson` и `operator ==`.
  test('замер видит каждое тело функции', () {
    final missed = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          if (entity.path.replaceAll(r'\', '/') case final path
              when !isGenerated(path))
            if ((
                  bodies: bodiesIn(entity.readAsStringSync()),
                  found: measure(path, entity.readAsStringSync()).length,
                )
                case (:final bodies, :final found) when bodies != found)
              '$path: тел $bodies, замер нашёл $found',
    ];
    expect(missed, isEmpty, reason: 'замер не узнал объявление');
  });

  // Замер грубый, но обязан быть предсказуемым: иначе храповик роняет
  // прогон на ровном месте или молчит там, где стоило бы сказать.
  group('замер', () {
    FunctionMetrics only(String source) => measure('x.dart', source).single;

    test('ветвление глубже весит больше', () {
      final flat = only('void f(bool a, bool b) { if (a) {} if (b) {} }');
      final nested = only('void f(bool a, bool b) { if (a) { if (b) {} } }');

      expect(flat.complexity, 2);
      expect(nested.complexity, 3);
      expect(nested.nesting, 2);
    });

    test('смена логического оператора стоит единицу, повтор — нет', () {
      expect(only('bool f(a, b, c) => a && b && c;').complexity, 1);
      expect(only('bool f(a, b, c) => a && b || c;').complexity, 2);
    });

    test('слова в строках и комментариях не считаются', () {
      final f = only('''
String f() {
  // if (x) { while (y) {} }
  return 'if else for while && ||';
}
''');
      expect(f.complexity, 0);
    });

    test('замыкание засчитывается той функции, где объявлено', () {
      final all = measure('x.dart', '''
class A {
  void run(List<int> xs) {
    xs.forEach((x) {
      if (x > 0) {}
    });
  }
}
''');
      expect(all.map((f) => f.name), ['A.run']);
      expect(all.single.complexity, 2);
    });

    test('методы называются вместе с классом, а стрелки считаются', () {
      final all = measure('x.dart', '''
class A {
  int get size => 1;
  Widget build(BuildContext context) => const SizedBox();
}
int top(int x) => x > 0 ? x : -x;
''');
      expect(all.map((f) => f.name), ['A.size', 'A.build', 'top']);
      expect(all.last.complexity, 1);
    });

    // Каждая форма ниже прежде проходила мимо замера — и мимо ворот.
    group('объявления, которые замер не видел', () {
      const shapes = {
        'конструктор со списком инициализации': (
          '''
class A {
  A(int x) : _x = x, super() {
    if (x > 0) {}
  }
  final int _x;
}
''',
          'A.A',
        ),
        'именованный конструктор': (
          'class A { A.empty() { if (true) {} } }',
          'A.A.empty',
        ),
        'фабрика стрелкой': (
          '''
class A {
  factory A.fromJson(Map<String, dynamic> json) =>
      json.isEmpty ? A.empty() : A.empty();
}
''',
          'A.A.fromJson',
        ),
        'оператор равенства': (
          'class A { bool operator ==(Object other) => other is A; }',
          'A.operator ==',
        ),
        'тип-запись в возврате': (
          '({int a, int b}) pair() { return (a: 1, b: 2); }',
          'pair',
        ),
        'тип-функция в возврате': (
          'void Function() later() => () {};',
          'later',
        ),
      };
      for (final MapEntry(key: shape, value: (source, name))
          in shapes.entries) {
        test(shape, () {
          expect(measure('x.dart', source).map((f) => f.name), [name]);
          expect(bodiesIn(source), 1);
        });
      }

      test('конструктор без тела функцией не считается', () {
        const source =
            'class A { const A(this.x) : assert(x > 0); final int x; }';
        expect(measure('x.dart', source), isEmpty);
        expect(bodiesIn(source), 0);
      });

      test('условие перед вызовом не принимается за тип возврата', () {
        const source = 'void f(bool a) { if (a) g(1); }\nvoid g(int x) {}';
        expect(measure('x.dart', source).map((f) => f.name), ['f', 'g']);
      });

      test('поле со значением-замыканием — не тело', () {
        const source = '''
class A {
  final void Function(int) onTap = (x) {};
  static const table = {1: 2};
  int get size => table.length;
}
''';
        expect(bodiesIn(source), 1);
        expect(measure('x.dart', source).map((f) => f.name), ['A.size']);
      });
    });
  });
}

/// Пусто, и это не случайность: пятнадцать ветвлений в одной функции —
/// потолок, за которым её перестают читать целиком. Новое нарушение
/// лечится ранним выходом, таблицей или именованным шагом.
const _complexity = <String>[];

/// Пусто. Последней держалась `Game.copyWith` — двадцать семь полей, по
/// строке в параметрах и по строке в вызове, — и ушла она не переносом
/// строк, а разбором модели на значения: полей у игры стало пятнадцать.
const _lines = <String>[];

/// Пусто, и пополнять нечем: вложенность глубже трёх лечится ранним
/// выходом или своей функцией — это всегда дешевле, чем запись здесь.
const _nesting = <String>[];
