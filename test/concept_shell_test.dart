import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('клавиша темы перебирает все три состояния', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    expect(harness.settings.state.themeMode, ThemeMode.system);

    // Прежде клавиша переключала тёмное со светлым и молча съедала «как в
    // системе»: вернуть его было можно только в настройках.
    for (final (tooltip, mode) in [
      ('Светлая тема', ThemeMode.light),
      ('Тёмная тема', ThemeMode.dark),
      ('Как в системе', ThemeMode.system),
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(harness.settings.state.themeMode, mode);
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
    expect(find.text('[ 01 / КОЛЛЕКЦИЯ ]'), findsOneWidget);
    expect(find.text('ТЕСТОВАЯ ОРБИТА'), findsOneWidget);
    expect(find.text('Открыть игру'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('пункты верхнего меню выровнены по вертикальному центру', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    final menuCenter = tester.getCenter(
      find.byKey(const ValueKey('concept-navigation')),
    );
    for (final label in ['БИБЛИОТЕКА', 'ЗАГРУЗКИ', 'СОХРАНЕНИЯ', 'НАСТРОЙКИ']) {
      expect(
        tester.getCenter(find.text(label).first).dy,
        closeTo(menuCenter.dy, 1),
      );
    }
    expect(find.text('VK'), findsNothing);
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
    expect(find.text('Добавить игру'), findsOneWidget);
    expect(filterCenter.dx, lessThan(actionCenter.dx));
    expect(actionCenter.dx, lessThan(searchCenter.dx));
    expect(actionCenter.dy, closeTo(filterCenter.dy, 1));
    expect(searchCenter.dy, closeTo(filterCenter.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
