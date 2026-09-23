import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/featured_game.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:evaporate/ui/library/library_body.dart';
import 'package:evaporate/ui/library/library_grid.dart';
import 'package:evaporate/ui/library/rise_in.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  late Directory tmp;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Библиотека из установленной игры и двух неустановленных.
  Future<TestHarness> withGames(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Альфа', status: GameStatus.installed);
    harness.addGame(title: 'Бета');
    harness.addGame(title: 'Гамма');
    await harness.pump(tester);
    return harness;
  }

  testWidgets('библиотека показывается сеткой обложек', (tester) async {
    await withGames(tester);

    expect(find.byType(GameCoverTile), findsNWidgets(3));
    // Пополнение библиотеки — одна клавиша с меню: «Найти установленные» и
    // «Указать источник» делали одно и то же и стояли рядом равными по
    // виду, а выбирать между ними приходилось до того, как станет понятно,
    // чем они различаются.
    expect(
      find.widgetWithText(OutlinedButton, 'Добавить игру'),
      findsOneWidget,
    );
    expect(find.text(l.findInstalledGames), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Добавить игру'));
    await tester.pumpAndSettle();
    expect(find.text(l.findInstalledGames), findsOneWidget);
    expect(find.text(l.addGameSource), findsOneWidget);
    // Обложек у этих игр нет, и плитка обязана назваться сама — иначе в
    // сетке остались бы три неразличимых прямоугольника.
    expect(find.text('Альфа'), findsOneWidget);
    expect(find.text('Гамма'), findsOneWidget);
  });

  testWidgets('полки делят библиотеку без остатка', (tester) async {
    await withGames(tester);

    // Числа рядом с названиями полок: всего три, установлена одна.
    expect(find.widgetWithText(TextButton, 'Все'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text(l.tabInstalled));
    await tester.pumpAndSettle();
    expect(find.byType(GameCoverTile), findsOneWidget);
    expect(find.text('Альфа'), findsOneWidget);

    await tester.tap(find.text(l.tabNotInstalled));
    await tester.pumpAndSettle();
    expect(find.byType(GameCoverTile), findsNWidgets(2));
    expect(find.text('Альфа'), findsNothing);
  });

  // Ленивая сетка узнаёт уже построенную плитку по ключу. Ключ уехал на
  // `MouseRegion` внутри плитки, и после отбора плитки собирались заново:
  // `RiseIn` всходил повторно, приподнятость терялась.
  testWidgets('после отбора плитка остаётся той же, а не собирается заново', (
    tester,
  ) async {
    await withGames(tester);
    State riseOf(String title) => tester.state(
      find.ancestor(of: find.text(title), matching: find.byType(RiseIn)),
    );
    final before = riseOf('Бета');

    // «Альфа» стояла первой и уходит: «Бета» сдвигается на её место.
    await tester.tap(find.text(l.tabNotInstalled));
    await tester.pumpAndSettle();

    expect(riseOf('Бета'), same(before));
  });

  // По этим числам страница догоняет фокусом ещё не построенную плитку.
  // Своя арифметика замера расходилась с сеткой: при 1280 пять столбцов
  // вместо шести, и возврат из игры в длинной библиотеке прыгал мимо.
  for (final width in [1280.0, 1100.0, 1600.0]) {
    testWidgets('замер сетки сходится с тем, как она разложена: $width', (
      tester,
    ) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      for (var i = 0; i < 14; i++) {
        harness.addGame(title: 'Игра $i');
      }
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await harness.pump(tester);

      final grid = tester.getSize(find.byType(GridView)).width;
      final tops = [
        for (final tile in tester.widgetList(find.byType(GameCoverTile)))
          tester.getTopLeft(find.byWidget(tile)).dy,
      ];
      final firstRow = tops.where((top) => top == tops.first).length;
      final secondRow = tops.firstWhere((top) => top > tops.first);
      final layout = LibraryGrid.layoutFor(grid, 1);

      expect(layout.columns, firstRow, reason: 'столбцов при $width');
      expect(
        layout.rowStride,
        moreOrLessEquals(secondRow - tops.first),
        reason: 'шаг ряда при $width',
      );
    });
  }

  testWidgets('нажатие на плитку открывает страницу игры', (tester) async {
    final harness = await withGames(tester);

    await tester.tap(find.text('Бета'));
    await tester.pumpAndSettle();

    expect(find.text(l.savePaths), findsOneWidget);
    expect(find.byType(GameCoverTile), findsNothing);
    expect(
      harness.library.state.gameById(harness.nav.state.openedGameId)?.title,
      'Бета',
    );
  });

  testWidgets('Escape возвращает из игры в сетку', (tester) async {
    final harness = await withGames(tester);

    await tester.tap(find.text('Бета'));
    await tester.pumpAndSettle();
    expect(find.byType(GameCoverTile), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(GameCoverTile), findsNWidgets(3));
    expect(harness.nav.state.openedGameId, isNull);
    // Курсор остаётся на той игре, с которой уходили.
    expect(
      harness.library.state.gameById(harness.nav.state.selectedGameId)?.title,
      'Бета',
    );
  });

  testWidgets('кнопка «К библиотеке» тоже возвращает', (tester) async {
    final harness = await withGames(tester);

    await tester.tap(find.text('Гамма'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.backToLibrary));
    await tester.pumpAndSettle();

    expect(find.byType(GameCoverTile), findsNWidgets(3));
    expect(harness.nav.state.openedGameId, isNull);
  });

  testWidgets('выбор идёт за фокусом, а не за нажатием', (tester) async {
    final harness = await withGames(tester);

    final tile = find.ancestor(
      of: find.text('Гамма'),
      matching: find.byType(GameCoverTile),
    );
    Focus.of(
      tester.element(find.descendant(of: tile, matching: find.text('Гамма'))),
    ).requestFocus();
    await tester.pumpAndSettle();

    // Страница не открылась, но «Играть» уже знает, о какой игре речь.
    expect(find.byType(GameCoverTile), findsNWidgets(3));
    expect(
      harness.library.state.gameById(harness.nav.state.selectedGameId)?.title,
      'Гамма',
    );
  });

  // Выбранная игра и клавиша запуска — то, ради чего открывают библиотеку.
  // Прятать их там, где просто меньше места по высоте, неправильно: кадр
  // сжимается в полосу и уходит совсем только в совсем низком окне.
  testWidgets('витрина не исчезает в невысоком окне, а становится полосой', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Альфа', status: GameStatus.installed);

    Future<void> resize(double height) async {
      tester.view.physicalSize = Size(1400, height);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(
      tester.widget<FeaturedGame>(find.byType(FeaturedGame)).compact,
      isFalse,
    );
    final full = tester.getSize(find.byType(FeaturedGame)).height;

    await resize(760);
    final compact = tester.widget<FeaturedGame>(find.byType(FeaturedGame));
    expect(compact.compact, isTrue);
    expect(
      tester.getSize(find.byType(FeaturedGame)).height,
      lessThan(full),
      reason: 'полоса обязана быть ниже полного кадра',
    );
    // Клавиша запуска остаётся на месте — она и есть смысл кадра.
    expect(find.text('Играть'), findsOneWidget);
    expect(find.text(l.openGame), findsOneWidget);
    expect(tester.takeException(), isNull);

    // А вот в совсем низком окне кадр уступает место самой полке.
    await resize(420);
    expect(find.byType(FeaturedGame), findsNothing);
    expect(find.byType(GameCoverTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('витрина показывает обложку выбранной игры', (tester) async {
    final harness = await withGames(tester);
    final cover = File('assets/branding/app_icon.png').absolute;
    final beta = harness.library.state.games.firstWhere(
      (game) => game.title == 'Бета',
    );
    harness.seedGame(
      beta.copyWith(details: beta.details.copyWith(coverPath: cover.path)),
    );
    harness.nav.add(GameSelected(beta.id));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('featured-game-background')),
    );
    // Расшифровка — под ширину окна, а не в полный размер файла.
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as FileImage).file.path, cover.path);
    expect(resized.width, isNotNull);
  });

  testWidgets('исчезнувшая игра не оставляет открытой страницы', (
    tester,
  ) async {
    final harness = await withGames(tester);

    // Игру могли удалить с другого экрана, пока её страница открыта. Здесь
    // это подделано ссылкой в никуда: настоящее удаление пишет библиотеку на
    // диск, а файловый ввод-вывод внутри testWidgets не завершается.
    harness.nav.add(const GameOpened('игра-которой-нет'));
    await tester.pumpAndSettle();

    expect(harness.nav.state.openedGameId, isNull);
    expect(find.byType(GameCoverTile), findsNWidgets(3));
  });

  testWidgets('наведение курсора выбирает игру и держит выбор', (tester) async {
    final harness = await withGames(tester);
    final first = harness.library.state.games.first.id;
    expect(harness.nav.state.selectedGameId, first);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).at(2)));
    await tester.pumpAndSettle();

    final third = harness.library.state.games[2].id;
    expect(harness.nav.state.selectedGameId, third);
    // Крупный кадр наверху идёт за выбором — ради него всё и затевалось.
    expect(
      tester.widget<FeaturedGame>(find.byType(FeaturedGame)).game.id,
      third,
    );

    // Выбор остаётся, когда курсор уходит с плитки: иначе до клавиш
    // крупного кадра было бы не добраться — он сменился бы раньше, чем
    // рука дойдёт до «Играть».
    await mouse.moveTo(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(harness.nav.state.selectedGameId, third);
  });

  // Наведение перестраивало всю страницу — сетку, крупный кадр и свет, —
  // а следом ещё раз от выбора игры. Плитка теперь сама знает, что она
  // под курсором, и страница от наведения не перестраивается.
  testWidgets('наведение на выбранную игру поднимает плитку, а не страницу', (
    tester,
  ) async {
    await withGames(tester);
    final body = tester.widget<LibraryBody>(find.byType(LibraryBody));
    double lift(int index) => tester
        .widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.byType(GameCoverTile).at(index),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        )
        .transform!
        .getTranslation()
        .y;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    // Первая игра и так выбрана: выбор не сменится, и перестраиваться
    // странице не от чего.
    await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).first));
    await tester.pumpAndSettle();

    expect(lift(0), lessThan(0), reason: 'плитка под курсором поднята');
    expect(lift(1), 0);
    expect(
      tester.widget<LibraryBody>(find.byType(LibraryBody)),
      same(body),
      reason: 'страница перестроилась от наведения',
    );
  });
}
