import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/ui/library/featured_game.dart';
import 'package:evaporate/ui/library/game_cover_tile.dart';
import 'package:evaporate/ui/library/library_body.dart';
import 'package:evaporate/ui/library/library_empty_state.dart';
import 'package:evaporate/ui/library/library_toolbar.dart';
import 'package:evaporate/ui/library/toolbar/library_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../support/test_app.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Библиотека много длиннее окна: восемьдесят игр — шестнадцать рядов
  /// при 1280. Названия с нулями, чтобы порядок полки совпал с номером.
  Future<(TestHarness, List<String>)> longLibrary(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    final ids = [
      for (var i = 0; i < 80; i++)
        harness.addGame(title: 'Игра ${i.toString().padLeft(2, '0')}'),
    ];
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    // Отложенная запись библиотеки на диск.
    await tester.pump(const Duration(milliseconds: 500));
    return (harness, ids);
  }

  /// Место раздела между полосами каркаса — то, что видно не сквозь стекло.
  Rect page(WidgetTester tester) => tester.getRect(find.byType(LibraryBody));

  Finder tile(int index) => find.ancestor(
    of: find.text('Игра ${index.toString().padLeft(2, '0')}'),
    matching: find.byType(GameCoverTile),
  );

  /// Прямоугольник того, что сейчас в фокусе, и его хозяин на странице.
  ({Rect rect, bool inToolbar, bool inHero}) focused() {
    final context = primaryFocus!.context!;
    return (
      rect: primaryFocus!.rect,
      inToolbar:
          context.findAncestorWidgetOfExactType<LibraryToolbar>() != null,
      inHero: context.findAncestorWidgetOfExactType<FeaturedGame>() != null,
    );
  }

  // Прежде прокручивалась одна сетка: подпись, кадр и полки стояли на
  // месте, под верхнюю полосу не уходило ничего, и стеклу было нечего
  // размыть.
  testWidgets('крупный кадр и полки уходят вверх вместе с сеткой', (
    tester,
  ) async {
    await longLibrary(tester);
    final hero = find.byType(FeaturedGame);
    final toolbar = find.byType(LibraryToolbar);
    final before = (
      hero: tester.getRect(hero).top,
      toolbar: tester.getRect(toolbar).top,
      tile: tester.getRect(tile(0)).top,
    );

    await tester.drag(tile(0), const Offset(0, -300));
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

  // По месту в сетке страница догоняет ещё не построенную плитку. Ряд
  // отмерялся от начала страницы, а над сеткой подпись, кадр и полки:
  // возврат к дальней плитке промахивался на их высоту.
  testWidgets('переход к дальней плитке ставит её ряд под верхнюю полосу', (
    tester,
  ) async {
    await longLibrary(tester);
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;

    grid.scrollTo(38);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(tile(38)).top,
      moreOrLessEquals(page(tester).top, epsilon: 0.5),
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

  // Всё на странице прокручивается, и прижатого нет ничего: до полок и
  // кадра, уехавших под полосу, доводит сам фокус — и ставит их не под
  // стекло, а к краю видимого. Путь — крестовиной: стрелки клавиатуры в
  // поле поиска остаются полю.
  testWidgets('вверх из первого ряда фокус идёт через полки к клавишам '
      'крупного кадра, и каждая выезжает из-под полосы', (tester) async {
    final (harness, _) = await longLibrary(tester);
    Focus.of(
      tester.element(
        find.descendant(of: tile(0), matching: find.text('Игра 00')),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(FeaturedGame, skipOffstage: false)).bottom,
      lessThan(page(tester).top),
      reason: 'кадр должен был уйти под полосу, иначе проверять нечего',
    );

    final path = <({Rect rect, bool inToolbar, bool inHero})>[];
    for (var step = 0; step < 3; step++) {
      await harness.tapButton(tester, GamepadButton.dpadUp);
      path.add(focused());
    }

    expect([for (final stop in path) stop.inToolbar], [true, true, false]);
    expect(path.last.inHero, isTrue, reason: 'от полок — к клавишам кадра');
    for (final stop in path) {
      expect(stop.rect.top, greaterThanOrEqualTo(page(tester).top));
    }
  });

  testWidgets('стрелка вверх из первого ряда уводит в полки', (tester) async {
    await longLibrary(tester);
    Focus.of(
      tester.element(
        find.descendant(of: tile(0), matching: find.text('Игра 00')),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(focused().inToolbar, isTrue);
    expect(focused().rect.top, greaterThanOrEqualTo(page(tester).top));
  });

  testWidgets('просьба о поиске выводит поле из-под полосы', (tester) async {
    final (harness, _) = await longLibrary(tester);
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;
    grid.scroll.jumpTo(grid.scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final search = find.byType(LibrarySearchField, skipOffstage: false);
    expect(tester.getRect(search).bottom, lessThan(page(tester).top));

    harness.nav.add(const SearchFocusRequested());
    await tester.pumpAndSettle();

    expect(
      tester.widget<LibrarySearchField>(search).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.getRect(search).top, greaterThanOrEqualTo(page(tester).top));
  });

  // Остаток видимого под полками — до строки подсказок, а не до края окна
  // прокрутки под ней: иначе пустая полка вставала бы ниже середины, а
  // страница, которой нечего показать, прокручивалась бы на высоту строки.
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
}
