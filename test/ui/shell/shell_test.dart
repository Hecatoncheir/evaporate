import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Finder crumb(String label) =>
      find.descendant(of: find.byType(EvTopBar), matching: find.text(label));

  // Дневной схемы у прототипа нет (0013): клавиши смены оформления в
  // полосе нет, а тема одна — тёмная, с токенами прототипа поверх
  // токенов приложения, иначе не нарисовать ни каркас, ни прежние страницы.
  testWidgets('схема одна — тёмная, и её не переключить из полосы', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final context = tester.element(find.byType(EvTopBar));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).extension<EvTheme>(), isNotNull);
    expect(find.byTooltip('Светлая тема'), findsNothing);
    expect(find.byTooltip('Как в системе'), findsNothing);
  });

  testWidgets('игра появляется в кинематографичном блоке библиотеки', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тестовая орбита');

    await harness.pump(tester);

    expect(find.text(l.sectionLibraryLabel), findsOneWidget);
    expect(find.text('ТЕСТОВАЯ ОРБИТА'), findsOneWidget);
    expect(find.text(l.openGame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('клавиши рейла стоят колонкой по порядку разделов', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final rail = tester.getRect(find.byKey(const ValueKey('navigation-rack')));
    var above = double.negativeInfinity;
    for (final section in AppSection.values) {
      final center = tester.getCenter(
        find.byKey(ValueKey('rail-${section.name}')),
      );
      expect(rail.contains(center), isTrue, reason: section.name);
      // Порядок рейла — порядок разделов и номеров в метках страниц.
      expect(center.dy, greaterThan(above), reason: section.name);
      above = center.dy;
    }
  });

  // Данных о друзьях и профиле у приложения нет — их места в рейле нет.
  testWidgets('рейл не показывает друзей и профиль', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.byKey(const ValueKey('rail-friends')), findsNothing);
    expect(find.bySemanticsLabel(l.evSectionFriends), findsNothing);
    expect(find.bySemanticsLabel(RegExp(l.evSectionProfile)), findsNothing);
  });

  testWidgets('крошка называет открытый раздел', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    expect(crumb('EVAPORATE'), findsOneWidget);
    expect(crumb(l.library), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-saves')));
    await tester.pumpAndSettle();
    expect(crumb(l.saves), findsOneWidget);
    expect(crumb(l.library), findsNothing);
    expect(harness.nav.state.section, AppSection.saves);
  });

  testWidgets('крошка и клавиши окна стоят посередине высоты полосы', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final bar = tester.getRect(find.byType(EvTopBar));
    for (final part in [
      crumb('EVAPORATE'),
      find.byKey(const ValueKey('rail-quit')),
    ]) {
      expect(tester.getCenter(part).dy, closeTo(bar.center.dy, 1));
    }
  });

  testWidgets('панель библиотеки разделяет фильтры, действия и поиск', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тестовая игра');
    tester.view.physicalSize = const Size(1450, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await harness.pump(tester);

    final filters = find.byKey(const ValueKey('library-filter-group'));
    final actions = find.byKey(const ValueKey('library-actions-group'));
    final search = find.byKey(const ValueKey('library-search'));
    final filterCenter = tester.getCenter(filters);
    final actionCenter = tester.getCenter(actions);
    final searchCenter = tester.getCenter(search);

    expect(find.text(l.addGame), findsOneWidget);
    expect(filterCenter.dx, lessThan(actionCenter.dx));
    expect(actionCenter.dx, lessThan(searchCenter.dx));
    expect(actionCenter.dy, closeTo(filterCenter.dy, 1));
    expect(searchCenter.dy, closeTo(filterCenter.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
