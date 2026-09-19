import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/ui/settings/pickers.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:evaporate/ui/widgets/scale_control.dart';
import 'package:evaporate/ui/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> openSettings(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    harness.nav.add(const SectionSelected(3));
    await tester.pumpAndSettle();
    return harness;
  }

  /// В какой карточке лежит виджет.
  String cardOf(WidgetTester tester, Finder inner) => tester
      .widget<SectionCard>(
        find.ancestor(of: inner, matching: find.byType(SectionCard)).first,
      )
      .title;

  testWidgets('язык и тема лежат в карточке вида, а не в сохранениях', (
    tester,
  ) async {
    await openSettings(tester);

    // Не вкусовщина, а ошибка раскладки: искать язык в «Сохранениях»
    // никто не станет.
    expect(cardOf(tester, find.byType(LanguagePicker)), 'Вид и язык');
    expect(cardOf(tester, find.byType(ThemePicker)), 'Вид и язык');
    expect(cardOf(tester, find.byType(WindowStartPicker)), 'Окно и запуск');
  });

  testWidgets('крупность обложек задаётся в библиотеке, а не в настройках', (
    tester,
  ) async {
    await openSettings(tester);

    // Один орган управления — одно место. Ползунок обложек виден там, где
    // видны сами обложки; здесь остаётся только масштаб интерфейса.
    final inSettings = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(ScaleControl),
    );
    expect(inSettings, findsOneWidget);
    expect(
      tester.widget<ScaleControl>(inSettings).key,
      const ValueKey('interface-scale'),
    );
  });

  testWidgets('перезапуск движка остался только на загрузках', (tester) async {
    final harness = await openSettings(tester);

    expect(
      find.descendant(
        of: find.byType(SettingsPage),
        matching: find.text('Перезапустить движок'),
      ),
      findsNothing,
    );

    harness.nav.add(const SectionSelected(1));
    await tester.pumpAndSettle();

    // Движок в тестах не поднят, и клавиша на месте: прежде она
    // показывалась только на отказе, и остановленный движок поднять было
    // нечем.
    expect(find.text('Перезапустить движок'), findsOneWidget);
  });

  testWidgets('украшения выбираются набором, а не тринадцатью галочками', (
    tester,
  ) async {
    final harness = await openSettings(tester);
    final scrollable = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final card = find.byKey(const ValueKey('living-library-settings'));
    await tester.scrollUntilVisible(card, 400, scrollable: scrollable);
    await tester.pumpAndSettle();

    // На свежих настройках горит «Обычно», а отдельных переключателей на
    // виду нет вовсе.
    expect(find.text('Обычно'), findsOneWidget);
    expect(find.byKey(const ValueKey('effects-portal-toggle')), findsNothing);

    await tester.tap(find.text('Спокойно'));
    await tester.pumpAndSettle();

    expect(harness.settings.state.libraryEffects, isTrue);
    expect(harness.settings.state.portalEnabled, isFalse);
    expect(harness.settings.state.interfaceAnimationsEnabled, isTrue);

    // Под «Подробно» флаги на месте — и каждое украшение по-прежнему своё.
    await tester.tap(find.byKey(const ValueKey('effects-details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('effects-portal-toggle')), findsOneWidget);
  });

  // Пустой выбор у наборов разрешён, и повторное нажатие на горящий
  // сегмент отдаёт пустое множество — обработчик брал у него `first`.
  testWidgets('нажатие на уже выбранный набор украшений ничего не ломает', (
    tester,
  ) async {
    final harness = await openSettings(tester);
    final before = harness.settings.state;
    final standard = find.descendant(
      of: find.byKey(const ValueKey('effects-preset')),
      matching: find.text('Обычно'),
    );
    await tester.ensureVisible(standard);
    await tester.pumpAndSettle();

    await tester.tap(standard);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(harness.settings.state, before);
  });
}
