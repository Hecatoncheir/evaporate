import 'package:evaporate/ui/shell/rail_tooltip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Подсказка у клавиши обоймы: сбоку, под курсором и в фокусе.
void main() {
  final button = FocusNode();
  tearDownAll(button.dispose);

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    hostWidget(
      Align(
        alignment: Alignment.topLeft,
        child: RailTooltip(
          message: 'Загрузки',
          child: SizedBox.square(
            dimension: 48,
            child: TextButton(
              focusNode: button,
              onPressed: () {},
              child: const Icon(Icons.download),
            ),
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('rail-tooltip')))
      .opacity;

  testWidgets('подсказка появляется под курсором и гаснет без него', (
    tester,
  ) async {
    await show(tester);
    expect(opacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);

    await mouse.moveTo(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(opacity(tester), 0);
  });

  // С геймпада и клавиатуры клавиши обоймы узнаются только по подсказке:
  // подписей на них нет.
  testWidgets('подсказка появляется и в фокусе', (tester) async {
    await show(tester);

    button.requestFocus();
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);

    button.unfocus();
    await tester.pumpAndSettle();
    expect(opacity(tester), 0);
  });

  // Сбоку, в сторону содержимого: сверху подсказка закрыла бы соседнюю
  // клавишу колонки.
  testWidgets('подсказка стоит справа от клавиши', (tester) async {
    await show(tester);
    button.requestFocus();
    await tester.pumpAndSettle();

    final key = tester.getRect(find.byType(TextButton));
    final tip = tester.getRect(find.text('Загрузки'));
    expect(tip.left, greaterThan(key.right));
    expect(tip.center.dy, closeTo(key.center.dy, 2));
  });
}
