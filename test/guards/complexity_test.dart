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
/// правила (этап 5 первого разбора, `docs/reviews/2026-09-19.md`).
/// Выросло число — это новое нарушение;
/// уменьшилось — число в списке правят вслед; опустилось до порога —
/// запись вычёркивают.
const maxComplexity = 15;
const maxLines = 60;
const maxNesting = 3;

void main() {
  final sources = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        if (entity.path.replaceAll(r'\', '/') case final path
            when !isGenerated(path))
          (path: path, text: entity.readAsStringSync()),
  ];
  final functions = [
    for (final (:path, :text) in sources) ...measure(path, text),
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

  // Замер читает дерево разбора, и дерево с ошибками он прочёл бы молча,
  // мимо нераспознанного. Анализатор приложения такой файл не пропустил
  // бы — значит, ошибка здесь говорит, что язык опередил пакет `analyzer`
  // в dev-зависимостях и его пора поднять.
  test('замер разбирает каждый файл без ошибок', () {
    expect([
      for (final (:path, :text) in sources)
        for (final error in parseErrors(text)) '$path: $error',
    ], isEmpty);
    expect(functions.length, greaterThan(1000), reason: 'замер ослеп');
  });

  // Замер обязан быть предсказуемым: иначе храповик роняет прогон на
  // ровном месте или молчит там, где стоило бы сказать. Числа — по
  // спецификации когнитивной сложности SonarSource.
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
      expect(only('bool f(a, b, c) => a && (b && c);').complexity, 1);
      // Отрицание последовательность рвёт: внутри скобок своя.
      expect(only('bool f(a, b, c) => a && !(b && c);').complexity, 2);
    });

    // Прежде вторая последовательность в соседнем элементе списка сливалась
    // с первой: между ними не было ни `;`, ни скобки блока.
    test('последовательности в соседних элементах коллекции — разные', () {
      final f = only(
        'List<int> f(a, b, c, d) => [if (a && b) 1, if (c && d) 2];',
      );
      expect(f.complexity, 4);
    });

    test('else и else if стоят единицу без надбавки за глубину', () {
      final f = only('''
void f(int x) {
  if (x > 0) {
  } else if (x < 0) {
  } else {
  }
}
''');
      expect(f.complexity, 3);
    });

    test('ветви тернарника вложены в него', () {
      expect(only('int f(a, b) => a ? 1 : b ? 2 : 3;').complexity, 3);
    });

    test('условие when у образца стоит единицу, а switch — один раз', () {
      final f = only('''
int f(Object x) => switch (x) {
  int n when n > 0 => 1,
  int() => 2,
  _ => 0,
};
''');
      expect(f.complexity, 2);
    });

    // Сокращения, заменяющие ветвление, читаются легче него — SonarSource
    // их не считает, и мы тоже.
    test('?? и ?. не считаются', () {
      expect(only('int f(A? a) => a?.b?.c ?? 0;').complexity, 0);
    });

    test('catch и переход к метке считаются', () {
      final caught = only('''
void f() {
  try {
  } on FormatException catch (_) {
  } catch (_) {
  }
}
''');
      expect(caught.complexity, 2);

      final labelled = only('''
void f() {
  outer:
  for (;;) {
    for (;;) {
      break outer;
    }
  }
}
''');
      expect(labelled.complexity, 4);
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
      expect(all.single.nesting, 2);
    });

    test('замыкание-стрелка тоже повышает вложенность', () {
      final f = only('void f(List<int> xs) => xs.map((x) => x > 0 ? x : 0);');
      expect(f.complexity, 2);
      expect(f.nesting, 0, reason: 'блоков в нём нет');
    });

    test('локальная функция — часть той, где объявлена', () {
      final f = only('void f() { void g(bool a) { if (a) {} } }');
      expect(f.complexity, 2);
    });

    test('литерал коллекции вложенностью не считается', () {
      final f = only("Map<String, Object> f() => {'a': {'b': {'c': 1}}};");
      expect(f.nesting, 0);
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
    group('объявления, которые разбор текстом не видел', () {
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
          'A.new',
        ),
        'список инициализации без тела': (
          'class A { A(int x) : _x = x > 0 ? x : 0; final int _x; }',
          'A.new',
        ),
        'именованный конструктор': (
          'class A { A.empty() { if (true) {} } }',
          'A.empty',
        ),
        'фабрика стрелкой': (
          '''
class A {
  factory A.fromJson(Map<String, dynamic> json) =>
      json.isEmpty ? A.empty() : A.empty();
}
''',
          'A.fromJson',
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
        'член расширения': (
          'extension on int { bool get even => this % 2 == 0; }',
          '.even',
        ),
      };
      for (final MapEntry(key: shape, value: (source, name))
          in shapes.entries) {
        test(shape, () {
          expect(measure('x.dart', source).map((f) => f.name), [name]);
        });
      }

      test('конструктору без тела и списка инициализации мерить нечего', () {
        const source = '''
class A {
  const A(this.x);
  factory A.other() = B;
  final int x;
}
''';
        expect(measure('x.dart', source), isEmpty);
      });

      test('поле со значением-замыканием — не функция', () {
        const source = '''
class A {
  final void Function(int) onTap = (x) {};
  static const table = {1: 2};
  int get size => table.length;
}
''';
        expect(measure('x.dart', source).map((f) => f.name), ['A.size']);
      });
    });

    test('ошибку разбора замер называет, а не проглатывает', () {
      expect(parseErrors('void f() { if (x }'), isNotEmpty);
      expect(parseErrors('void f() {}'), isEmpty);
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
