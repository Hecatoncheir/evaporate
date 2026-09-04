import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
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
    expect(
      find.widgetWithText(OutlinedButton, 'Найти установленные игры'),
      findsOneWidget,
    );
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

    await tester.tap(find.text('Установленные'));
    await tester.pumpAndSettle();
    expect(find.byType(GameCoverTile), findsOneWidget);
    expect(find.text('Альфа'), findsOneWidget);

    await tester.tap(find.text('Не установленные'));
    await tester.pumpAndSettle();
    expect(find.byType(GameCoverTile), findsNWidgets(2));
    expect(find.text('Альфа'), findsNothing);
  });

  testWidgets('нажатие на плитку открывает страницу игры', (tester) async {
    final harness = await withGames(tester);

    await tester.tap(find.text('Бета'));
    await tester.pumpAndSettle();

    expect(find.text('Папки сохранений'), findsOneWidget);
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
    await tester.tap(find.text('К библиотеке'));
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
}
