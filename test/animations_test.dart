import 'package:evaporate/ui/widgets/animated_progress.dart';
import 'package:evaporate/ui/widgets/fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Раздел, который помнит, сколько раз его нажали: по нему и видно,
/// пережил ли он переключение.
class _Counter extends StatefulWidget {
  const _Counter(this.label);

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.label}: $taps'),
    );
  }
}

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('переключение разделов', () {
    // Главное требование: раздел, куда вернулись, должен выглядеть так же,
    // как его оставили. `AnimatedSwitcher` этого бы не дал — он выбрасывает
    // прежнего ребёнка вместе с прокруткой, вводом и фокусом.
    testWidgets('состояние раздела переживает переключение', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => index = index == 0 ? 1 : 0),
                  child: const Text('сменить'),
                ),
                Expanded(
                  child: FadeIndexedStack(
                    index: index,
                    children: const [_Counter('первый'), _Counter('второй')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('первый: 0'));
      await tester.pumpAndSettle();
      expect(find.text('первый: 1'), findsOneWidget);

      await tester.tap(find.text('сменить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('сменить'));
      await tester.pumpAndSettle();

      expect(
        find.text('первый: 1'),
        findsOneWidget,
        reason: 'нажатие не должно потеряться при переходе туда и обратно',
      );
    });

    testWidgets('переход укладывается в отведённое время', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => index = 1),
                  child: const Text('сменить'),
                ),
                Expanded(
                  child: FadeIndexedStack(
                    index: index,
                    duration: const Duration(milliseconds: 150),
                    children: const [Text('раз'), Text('два')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('сменить'));
      await tester.pump();
      // На середине перехода новый раздел уже виден, но ещё не полностью.
      await tester.pump(const Duration(milliseconds: 75));
      final midway = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(FadeIndexedStack),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(midway.opacity.value, greaterThan(0.0));
      expect(midway.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      final settled = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(FadeIndexedStack),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(settled.opacity.value, 1.0);
    });

    testWidgets('без смены раздела ничего не анимируется', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FadeIndexedStack(
            index: 0,
            children: [Text('раз'), Text('два')],
          ),
        ),
      );

      final transition = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(FadeIndexedStack),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(transition.opacity.value, 1.0);
    });
  });

  group('полоса загрузки', () {
    testWidgets('значение доезжает, а не прыгает', (tester) async {
      await tester.pumpWidget(wrap(const AnimatedProgress(value: 0.8)));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final early = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(early, lessThan(0.8), reason: 'значение должно ехать постепенно');

      await tester.pumpAndSettle();
      final settled = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(settled, closeTo(0.8, 0.001));
    });

    testWidgets('неизвестный прогресс остаётся бегущим', (tester) async {
      await tester.pumpWidget(wrap(const AnimatedProgress(value: null)));
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);

      // Бегущая полоса анимируется бесконечно, поэтому pumpAndSettle
      // здесь повис бы: достаточно одного кадра.
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('значение вне диапазона не ломает полосу', (tester) async {
      await tester.pumpWidget(wrap(const AnimatedProgress(value: 1.7)));
      await tester.pumpAndSettle();

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(1.0, 0.001));
    });
  });
}
