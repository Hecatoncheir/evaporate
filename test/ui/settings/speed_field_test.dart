import 'package:evaporate/ui/settings/speed_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Поле скорости в настройках.
///
/// Число фиксировалось только по Enter и щелчку мимо, а страница настроек
/// нарочно уводит фокус из полей стрелками: поле продолжало показывать
/// набранное, которое никуда не записалось.
void main() {
  Future<List<int>> pumpField(WidgetTester tester, {int value = 0}) async {
    final changes = <int>[];
    await tester.pumpWidget(
      hostWidget(
        SpeedField(label: 'Загрузка', value: value, onChanged: changes.add),
      ),
    );
    return changes;
  }

  testWidgets('набранное фиксируется, когда фокус уходит сам', (tester) async {
    final changes = await pumpField(tester);

    await tester.enterText(find.byType(TextField), '250');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(changes, [250]);
  });

  testWidgets('без правки уход фокуса ничего не пишет', (tester) async {
    final changes = await pumpField(tester, value: 300);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(changes, isEmpty);
  });

  // Значение могли поменять и не здесь — например, набором настроек. Поле,
  // которое показывает прежнее, обмануло бы при следующем же уходе фокуса:
  // записало бы старое число поверх нового.
  testWidgets('значение, сменившееся снаружи, видно в поле', (tester) async {
    await pumpField(tester, value: 300);
    await pumpField(tester, value: 800);

    expect(find.text('800'), findsOneWidget);
  });
}
