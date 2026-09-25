import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/shell/ev_rail.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/widgets/ev_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Кнопка рейла сама по себе: метка задач и подсказка сбоку.
///
/// Подписей на кнопках рейла нет, поэтому раздел с клавиатуры и геймпада
/// узнают только по подсказке, а метка задач однажды уже наезжала на
/// значок, закрывая, куда ведёт кнопка.
Future<void> _pump(WidgetTester tester, {int? badge}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: EvRailItem(
              section: EvSection.downloads,
              tooltip: 'Загрузки · 3',
              active: false,
              onTap: () {},
              badge: badge,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _button(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(EvRailItem),
        matching: find.byType(AnimatedContainer),
      )
      .last,
);

void main() {
  for (final (count, label) in [(3, '3'), (123, '99+')]) {
    testWidgets('метка $label — в углу кнопки и не закрывает значок', (
      tester,
    ) async {
      await _pump(tester, badge: count);

      final badge = tester.getRect(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      final button = _button(tester);
      final icon = tester.getRect(find.byType(EvIcon));

      expect(button.contains(badge.topLeft), isTrue, reason: 'вне кнопки');
      expect(button.contains(badge.bottomRight), isTrue, reason: 'вне кнопки');
      expect(badge.contains(icon.center), isFalse, reason: 'закрыт значок');
      expect(badge.center.dx, greaterThan(icon.center.dx));
      expect(badge.center.dy, lessThan(icon.center.dy));
    });
  }

  testWidgets('без задач метки нет', (tester) async {
    await _pump(tester, badge: 0);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('подсказка появляется от фокуса с клавиатуры, справа', (
    tester,
  ) async {
    await _pump(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Загрузки · 3'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(opacity(), 1);
    final tip = tester.getRect(find.text('Загрузки · 3'));
    expect(tip.left, greaterThan(_button(tester).right));
  });
}
