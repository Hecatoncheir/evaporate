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

  /// Обложка плитки такой, какой её видно: подросшей под фокусом.
  Rect shownTile(WidgetTester tester, int index) => tester.getRect(
    find
        .descendant(
          of: find.descendant(
            of: tile(index),
            matching: find.byType(AnimatedScale),
          ),
          matching: find.byType(AnimatedContainer),
        )
        .first,
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

  /// Отдаёт фокус плитке [index] так, как его отдаёт возврат со страницы
  /// игры или Tab из поиска: мимо направленного обхода.
  Future<void> focusTile(WidgetTester tester, int index) async {
    final label = 'Игра ${index.toString().padLeft(2, '0')}';
    Focus.of(
      tester.element(
        find.descendant(of: tile(index), matching: find.text(label)),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
  }

  // Сетка — часть одной прокрутки со страницей, и доля 0.1, которой
  // плитка под фокусом подводила себя, двигала уже всю страницу: плитка
  // первого ряда, видная целиком, уносила под полосу крупный кадр с
  // клавишей «Играть» — с первого же нажатия. В 1440×900 под первым
  // рядом хватает места и на рост обложки под фокусом.
  testWidgets('фокус на плитке, видной целиком, страницу не двигает', (
    tester,
  ) async {
    await longLibrary(tester, window: const Size(1440, 900));
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;
    final hero = tester.getRect(find.byType(FeaturedGame));

    await focusTile(tester, 1);

    expect(grid.scroll.offset, 0);
    expect(tester.getRect(find.byType(FeaturedGame)), hero);
  });

  // В 1280×900 под первым рядом не хватает нескольких точек на рост
  // обложки: страница сдвигается на них, а не на полэкрана.
  testWidgets('фокус на плитке первого ряда крупный кадр не прячет', (
    tester,
  ) async {
    await longLibrary(tester);

    await focusTile(tester, 1);

    final hero = tester.getRect(find.byType(FeaturedGame));
    expect(hero.top, greaterThanOrEqualTo(page(tester).top));
    expect(hero.bottom, lessThanOrEqualTo(page(tester).bottom));
  });

  // В 1280×720 первый ряд виден не целиком. Доля 0.1 ставила его к
  // верхнему краю, и кадр уходил под полосу весь; довести ряд до нижнего
  // края — значит сдвинуть страницу ровно на недостающее.
  testWidgets('первый ряд, видный не целиком, фокус доводит до нижнего края '
      'видимого, и кадр остаётся на экране', (tester) async {
    await longLibrary(tester, window: const Size(1280, 720));
    expect(tester.getRect(tile(1)).bottom, greaterThan(page(tester).bottom));

    await focusTile(tester, 1);

    final grown = shownTile(tester, 1);
    expect(grown.bottom, moreOrLessEquals(page(tester).bottom, epsilon: 0.5));
    expect(
      tester.getRect(find.byType(FeaturedGame)).bottom,
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
      tester.getRect(find.byType(FeaturedGame)).top,
      greaterThanOrEqualTo(page(tester).top),
    );
  });

  testWidgets('плитку, наполовину ушедшую под полосу, фокус выводит в '
      'видимое', (tester) async {
    await longLibrary(tester);
    final grid = tester.widget<LibraryBody>(find.byType(LibraryBody)).grid;
    grid.scrollTo(20);
    grid.scroll.jumpTo(grid.scroll.offset + 100);
    await tester.pumpAndSettle();
    expect(tester.getRect(tile(20)).top, lessThan(page(tester).top));

    await focusTile(tester, 20);

    expect(
      tester.getRect(tile(20)).top,
      greaterThanOrEqualTo(page(tester).top),
    );
  });

  // Обход крестовиной подводит плитку вплотную к краю видимого, а под
  // фокусом она подрастает: без запаса на рост низ обложки с рамкой
  // выбранного уходил под строку подсказок.
  testWidgets('крестовина вниз выводит следующий ряд целиком, вместе с '
      'подросшей под фокусом обложкой', (tester) async {
    final (harness, ids) = await longLibrary(tester);
    final columns = tester
        .widget<LibraryBody>(find.byType(LibraryBody))
        .grid
        .columns;
    await focusTile(tester, 0);

    await harness.tapButton(tester, GamepadButton.dpadDown);

    expect(harness.nav.state.selectedGameId, ids[columns]);
    final grown = shownTile(tester, columns);
    expect(grown.top, greaterThanOrEqualTo(page(tester).top));
    expect(grown.bottom, lessThanOrEqualTo(page(tester).bottom));
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
    tester.widget<LibraryBody>(find.byType(LibraryBody)).grid.scrollTo(0);
    await tester.pump();
    await focusTile(tester, 0);
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

  testWidgets('стрелка вверх из первого ряда уводит в полки, и те выезжают '
      'из-под полосы', (tester) async {
    await longLibrary(tester);
    tester.widget<LibraryBody>(find.byType(LibraryBody)).grid.scrollTo(0);
    await tester.pump();
    await focusTile(tester, 0);
    expect(
      tester.getRect(find.byType(LibraryToolbar, skipOffstage: false)).bottom,
      lessThanOrEqualTo(page(tester).top),
      reason: 'полки должны были уйти под полосу, иначе проверять нечего',
    );

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
