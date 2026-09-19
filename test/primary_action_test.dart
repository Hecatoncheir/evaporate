import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/primary_action.dart';
import 'package:evaporate/ui/widgets/launcher_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Game game({
    GameStatus status = GameStatus.notInstalled,
    GameSource? source,
    String? executablePath,
  }) => Game(
    id: 'g',
    title: 'Игра',
    addedAt: DateTime(2026),
    status: status,
    source: source,
    executablePath: executablePath,
  );

  // Одно решение на четыре места: кнопка X, крупный кадр, подпись у его
  // клавиши и карточка на странице игры. Пока `switch` стоял в каждом,
  // одна игра могла получить с геймпада одно действие, а с кадра другое.
  group('главное действие игры', () {
    test('каждому состоянию отвечает одно действие', () {
      expect(
        primaryActionFor(game(status: GameStatus.running)),
        PrimaryAction.stop,
      );
      expect(
        primaryActionFor(game(status: GameStatus.downloading)),
        PrimaryAction.pause,
      );
      expect(
        primaryActionFor(game(status: GameStatus.paused)),
        PrimaryAction.resume,
      );
      expect(
        primaryActionFor(game(status: GameStatus.installed)),
        PrimaryAction.play,
      );
      expect(
        primaryActionFor(game(status: GameStatus.notInstalled)),
        PrimaryAction.download,
      );
      expect(
        primaryActionFor(game(status: GameStatus.error)),
        PrimaryAction.download,
      );
    });

    test('установленную без выбранного файла запускать нечем', () {
      expect(canDoPrimaryAction(game(status: GameStatus.installed)), isFalse);
      expect(
        canDoPrimaryAction(
          game(status: GameStatus.installed, executablePath: '/games/g.exe'),
        ),
        isTrue,
      );
    });

    test('без источника и из локальной папки скачивать нечего', () {
      expect(canDoPrimaryAction(game()), isFalse);
      expect(
        canDoPrimaryAction(
          game(
            source: const GameSource(
              kind: GameSourceKind.localFolder,
              value: '/games/g',
            ),
          ),
        ),
        isFalse,
      );
      expect(
        canDoPrimaryAction(
          game(
            source: const GameSource(
              kind: GameSourceKind.magnet,
              value: 'magnet:?xt=urn:btih:aaa',
            ),
          ),
        ),
        isTrue,
      );
    });

    test('у каждого действия своя подпись и свой значок', () {
      // Значок был один на все состояния, и «Пауза» подписывала клавишу с
      // треугольником «играть».
      final labels = PrimaryAction.values
          .map((action) => primaryActionLabel(LRu(), action))
          .toSet();
      final icons = PrimaryAction.values.map(primaryActionIcon).toSet();

      expect(labels.length, PrimaryAction.values.length);
      expect(
        primaryActionIcon(PrimaryAction.pause),
        isNot(primaryActionIcon(PrimaryAction.play)),
      );
      // Продолжить и играть — один жест, и значок у них общий.
      expect(icons.length, PrimaryAction.values.length - 1);
    });
  });

  group('крупный кадр библиотеки', () {
    late Directory tmp;

    setUp(() async => tmp = await TestHarness.makeTempDir());
    tearDown(() => TestHarness.removeTempDir(tmp));

    LauncherActionButton featured(WidgetTester tester) => tester
        .widget<LauncherActionButton>(find.byType(LauncherActionButton).first);

    testWidgets('клавиша подписана тем, что она сделает', (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      harness.addGame(
        title: 'Скачивается',
        status: GameStatus.downloading,
        source: const GameSource(
          kind: GameSourceKind.magnet,
          value: 'magnet:?xt=urn:btih:aaa',
        ),
      );

      await harness.pump(tester);

      expect(featured(tester).label, 'Пауза');
      expect(featured(tester).icon, Icons.pause_rounded);
      expect(featured(tester).onPressed, isNotNull);
    });

    testWidgets('нечего делать — клавиша погашена, а не мертва', (
      tester,
    ) async {
      // Прежде клавиша у игры без источника нажималась и не делала ничего:
      // «недоступно» проверялось только у установленной.
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      harness.addGame(title: 'Без источника');

      await harness.pump(tester);

      expect(featured(tester).label, 'Скачать');
      expect(featured(tester).onPressed, isNull);
    });
  });
}
