import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ступени моторики', () {
    test('длительности идут по возрастанию роли', () {
      const m = EvaporateMotion.standard;

      expect(m.instant, lessThan(m.fast));
      expect(m.fast, lessThan(m.base));
      expect(m.base, lessThan(m.slow));
    });

    // Без предела полка из шестидесяти игр всходила бы секунды, и нижние
    // ряды человек увидел бы уже после того, как начал их искать.
    test('задержка всхода перестаёт расти после предела', () {
      const m = EvaporateMotion.standard;

      expect(m.staggerAt(0), Duration.zero);
      expect(m.staggerAt(3), m.stagger * 3);
      expect(m.staggerAt(m.staggerLimit), m.stagger * m.staggerLimit);
      expect(m.staggerAt(999), m.staggerAt(m.staggerLimit));
    });

    test('выключенная моторика не двигается вовсе', () {
      const m = EvaporateMotion.still;

      expect(m.base, Duration.zero);
      expect(m.staggerAt(5), Duration.zero);
    });

    test('переход между наборами не спотыкается', () {
      final middle = EvaporateMotion.still.lerp(EvaporateMotion.standard, 0.5);

      expect(middle.base, EvaporateMotion.standard.base * 0.5);
    });
  });

  group('моторика приходит из контекста', () {
    testWidgets('тема несёт набор ступеней', (tester) async {
      late EvaporateMotion seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaporateTheme.dark(),
          home: Builder(
            builder: (context) {
              seen = context.motion;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, EvaporateMotion.standard);
    });

    // Проверять системную просьбу в каждом виджете значило бы однажды
    // забыть, а забытое место выглядит поломкой именно у того, кому
    // анимации мешают.
    testWidgets('просьба не двигаться гасит все ступени', (tester) async {
      late EvaporateMotion seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaporateTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                seen = context.motion;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(seen, EvaporateMotion.still);
    });

    // Тесты и превью часто поднимают голый MaterialApp без расширений.
    testWidgets('без расширения берётся стандартный набор', (tester) async {
      late EvaporateMotion seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = context.motion;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, EvaporateMotion.standard);
    });
  });
}
