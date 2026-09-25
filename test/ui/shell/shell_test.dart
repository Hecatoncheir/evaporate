import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/app_theme_mode.dart';
import 'package:evaporate/ui/shell/top_bar.dart';
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

  testWidgets('клавиша темы перебирает все три состояния', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    expect(harness.settings.state.appearance.themeMode, AppThemeMode.system);

    // Прежде клавиша переключала тёмное со светлым и молча съедала «как в
    // системе»: вернуть его было можно только в настройках.
    for (final (tooltip, mode) in [
      ('Светлая тема', AppThemeMode.light),
      ('Тёмная тема', AppThemeMode.dark),
      ('Как в системе', AppThemeMode.system),
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(harness.settings.state.appearance.themeMode, mode);
    }
  });

  testWidgets('игра появляется в кинематографичном блоке библиотеки', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тестовая орбита');

    await harness.pump(tester);

    // Раздел подписан меткой на корпусе, а лозунга и абзаца про библиотеку
    // здесь больше нет: их место занимает сама библиотека.
    expect(find.text(l.sectionLibraryLabel), findsOneWidget);
    expect(find.text('ТЕСТОВАЯ ОРБИТА'), findsOneWidget);
    expect(find.text(l.openGame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('клавиши обоймы стоят колонкой по её оси и по порядку', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final axis = tester
        .getCenter(find.byKey(const ValueKey('navigation-rack')))
        .dx;
    var above = double.negativeInfinity;
    for (final section in AppSection.values) {
      final center = tester.getCenter(
        find.byKey(ValueKey('rail-${section.name}')),
      );
      expect(center.dx, closeTo(axis, 1), reason: section.name);
      // Порядок обоймы — порядок разделов и номеров в метках страниц.
      expect(center.dy, greaterThan(above), reason: section.name);
      above = center.dy;
    }
    expect(find.text('VK'), findsNothing);
  });

  // Имя раздела на экране одно — в крошке верхней рейки, — и оно следует
  // за выбором: подписей на клавишах обоймы больше нет.
  testWidgets('крошка называет открытый раздел', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    expect(find.text('EVAPORATE'), findsOneWidget);
    expect(find.text('БИБЛИОТЕКА'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-saves')));
    await tester.pumpAndSettle();
    expect(find.text('СОХРАНЕНИЯ'), findsOneWidget);
    expect(find.text('БИБЛИОТЕКА'), findsNothing);
  });

  // Ряд, сжатый по самой высокой клавише, прижимался к верху рейки.
  testWidgets('крошка и клавиши рейки стоят посередине её высоты', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final bar = tester.getRect(find.byType(TopBar));
    for (final part in [
      find.text('EVAPORATE'),
      find.byTooltip('Светлая тема'),
    ]) {
      expect(tester.getCenter(part).dy, closeTo(bar.center.dy, 1));
    }
  });

  // Клавиша стоит посередине колонки, и отсчёт от её края клал подсказку
  // на кант обоймы.
  testWidgets('подсказки клавиш начинаются за краем обоймы', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final rack = tester.getRect(find.byKey(const ValueKey('navigation-rack')));
    final tips = find.byKey(const ValueKey('rail-tooltip'));
    expect(tips, findsNWidgets(AppSection.values.length));
    for (var i = 0; i < AppSection.values.length; i++) {
      expect(tester.getRect(tips.at(i)).left, greaterThan(rack.right));
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

    expect(find.text('БИБЛИОТЕКА'), findsOneWidget);
    expect(find.text(l.addGame), findsOneWidget);
    expect(filterCenter.dx, lessThan(actionCenter.dx));
    expect(actionCenter.dx, lessThan(searchCenter.dx));
    expect(actionCenter.dy, closeTo(filterCenter.dy, 1));
    expect(searchCenter.dy, closeTo(filterCenter.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
