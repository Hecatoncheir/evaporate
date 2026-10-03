import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/ui/ev/app/ev_library_card.dart';
import 'package:evaporate/ui/ev/app/ev_library_hero.dart';
import 'package:evaporate/ui/library/library_body.dart';
import 'package:evaporate/ui/library/library_empty_state.dart';
import 'package:evaporate/ui/library/library_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<(TestHarness, List<String>)> longLibrary(
    WidgetTester tester, {
    Size window = const Size(1280, 900),
  }) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    final ids = [
      for (var i = 0; i < 80; i++)
        harness.addGame(title: 'Игра ${i.toString().padLeft(2, '0')}'),
    ];
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    return (harness, ids);
  }

  Rect page(WidgetTester tester) => tester.getRect(find.byType(LibraryBody));

  Finder tile(int index) => find.ancestor(
    of: find.text('Игра ${index.toString().padLeft(2, '0')}'),
    matching: find.byType(EvLibraryCard),
  );

  Rect shownTile(WidgetTester tester, int index) => tester.getRect(
    find
        .descendant(of: tile(index), matching: find.byType(AnimatedContainer))
        .first,
  );

  testWidgets('крупный кадр и полки уходят вверх вместе с сеткой', (
    tester,
  ) async {
    await longLibrary(tester);
    final hero = find.byType(EvLibraryHero);
    final toolbar = find.byType(LibraryToolbar);
    final before = (
      hero: tester.getRect(hero).top,
      toolbar: tester.getRect(toolbar).top,
      tile: tester.getRect(tile(0)).top,
    );

    await tester.dragFrom(page(tester).center, const Offset(0, -300));
    await tester.pumpAndSettle();

    final moved = before.tile - tester.getRect(tile(0)).top;
    expect(moved, greaterThan(0), reason: 'сетка не прокрутилась');
    expect(before.hero - tester.getRect(hero).top, moreOrLessEquals(moved));
    expect(
      before.toolbar - tester.getRect(toolbar).top,
      moreOrLessEquals(moved),
    );
    expect(
      tester.getRect(hero).top,
      lessThan(page(tester).top),
      reason: 'кадр обязан уйти под верхнюю полосу, а не встать у её кромки',
    );
  });

  testWidgets('переход к дальней плитке ставит её ряд под верхнюю полосу', (
    tester,
  ) async {
    await longLibrary(tester);
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;

    grid.scrollTo(38);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(tile(38)).top,
      greaterThanOrEqualTo(page(tester).top),
    );
  });

  Future<void> focusTile(WidgetTester tester, int index) async {
    final label = 'Игра ${index.toString().padLeft(2, '0')}';
    Focus.of(
      tester.element(
        find.descendant(of: tile(index), matching: find.text(label)),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
  }

  testWidgets('фокус на плитке, видной целиком, страницу не двигает', (
    tester,
  ) async {
    await longLibrary(tester, window: const Size(1440, 1400));
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;
    final hero = tester.getRect(find.byType(EvLibraryHero));

    await focusTile(tester, 1);

    expect(grid.scroll.offset, 0);
    expect(tester.getRect(find.byType(EvLibraryHero)), hero);
  });

  testWidgets('фокус первого ряда сохраняет нижнюю часть кадра', (
    tester,
  ) async {
    await longLibrary(tester);

    await focusTile(tester, 1);

    final hero = tester.getRect(find.byType(EvLibraryHero));
    expect(hero.bottom, greaterThan(page(tester).top));
    expect(hero.bottom, lessThanOrEqualTo(page(tester).bottom));
  });

  testWidgets('первый ряд, видный не целиком, фокус доводит до нижнего края '
      'видимого, и кадр остаётся на экране', (tester) async {
    await longLibrary(tester, window: const Size(1280, 720));
    expect(tester.getRect(tile(1)).bottom, greaterThan(page(tester).bottom));

    await focusTile(tester, 1);

    final grown = shownTile(tester, 1);
    expect(grown.bottom, lessThanOrEqualTo(page(tester).bottom));
    expect(
      tester.getRect(find.byType(EvLibraryHero)).bottom,
      greaterThan(page(tester).top),
    );
  });

  testWidgets('со страницы игры из первого ряда возвращаются к крупному '
      'кадру на месте', (tester) async {
    final (harness, ids) = await longLibrary(tester);
    harness.nav
      ..add(GameSelected(ids[2]))
      ..add(GameOpened(ids[2]));
    await tester.pumpAndSettle();

    harness.nav.add(const GameOpened(null));
    await tester.pumpAndSettle();

    expect(primaryFocus?.debugLabel, 'game:${ids[2]}');
    expect(
      tester.getRect(find.byType(EvLibraryHero)).bottom,
      greaterThan(page(tester).top),
    );
  });

  testWidgets('со страницы дальней игры фокус возвращается на её плитку, '
      'и та видна между полосами', (tester) async {
    final (harness, ids) = await longLibrary(tester);
    harness.nav
      ..add(GameSelected(ids[63]))
      ..add(GameOpened(ids[63]));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryBody), findsNothing);

    harness.nav.add(const GameOpened(null));
    await tester.pumpAndSettle();

    expect(primaryFocus?.debugLabel, 'game:${ids[63]}');
    final rect = tester.getRect(tile(63));
    expect(rect.top, greaterThanOrEqualTo(page(tester).top));
    expect(rect.bottom, lessThanOrEqualTo(page(tester).bottom));
  });

  testWidgets('пустая полка стоит посередине видимого и страницу зря не '
      'прокручивает', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;

    expect(grid.scroll.position.maxScrollExtent, 0);
    final shelf = tester.getRect(find.byType(LibraryEmptyState));
    expect(shelf.top, tester.getRect(find.byType(LibraryToolbar)).bottom);
    expect(shelf.bottom, page(tester).bottom);
    expect(tester.takeException(), isNull);
  });
  testWidgets('фокус дальней карточки выводит её по обеим осям', (
    tester,
  ) async {
    await longLibrary(tester);
    await focusTile(tester, 63);
    final rect = tester.getRect(tile(63));
    final visible = page(tester);
    expect(rect.left, greaterThanOrEqualTo(visible.left));
    expect(rect.right, lessThanOrEqualTo(visible.right));
    expect(rect.top, greaterThanOrEqualTo(visible.top));
    expect(rect.bottom, lessThanOrEqualTo(visible.bottom));
  });
}
