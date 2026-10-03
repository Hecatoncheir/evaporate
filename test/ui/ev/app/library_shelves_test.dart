import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/ev/app/ev_library_card.dart';
import 'package:evaporate/ui/ev/app/ev_library_shelves.dart';
import 'package:evaporate/ui/ev/library/ev_session_row.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
import 'package:evaporate/ui/library/effects/foil/foil_card.dart';
import 'package:evaporate/ui/library/library_grid_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_app.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Game game(
    String id, {
    GameStatus status = GameStatus.notInstalled,
    DateTime? played,
  }) => Game(
    id: id,
    title: '$id.v1.2-GOG',
    addedAt: DateTime(2026),
    status: status,
    play: PlayStats(lastPlayed: played, playtime: const Duration(hours: 2)),
  );

  Future<(TestHarness, LibraryGridController)> show(
    WidgetTester tester,
    List<Game> games,
  ) async {
    final harness = TestHarness(tmp);
    final controller = LibraryGridController();
    addTearDown(harness.dispose);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.buildApp(
        builder: (context, child) => SingleChildScrollView(
          controller: controller.scroll,
          child: EvLibraryShelves(games: games, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (harness, controller);
  }

  testWidgets('состояния делят карточки на две полки без потери игр', (
    tester,
  ) async {
    final games = [
      for (final status in GameStatus.values) game(status.name, status: status),
    ];
    await show(tester, games);
    List<GameStatus> states(String key) => tester
        .widgetList<EvLibraryCard>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EvLibraryCard),
          ),
        )
        .map((card) => card.game.status)
        .toList();
    expect(states('installed-shelf'), [
      GameStatus.installed,
      GameStatus.running,
    ]);
    expect(states('incoming-shelf'), [
      GameStatus.notInstalled,
      GameStatus.downloading,
      GameStatus.paused,
      GameStatus.error,
    ]);
    expect(find.byType(EvLibraryCard), findsNWidgets(GameStatus.values.length));
    expect(find.byType(EvSessionRow), findsNothing);
  });

  testWidgets(
    'Продолжить содержит шесть последних запусков, без выдуманных подписей',
    (tester) async {
      await show(tester, [
        for (var i = 0; i < 8; i++)
          game('Game $i', played: DateTime(2026, 9, i + 1)),
        game('Unplayed'),
      ]);
      final rows = tester
          .widgetList<EvSessionRow>(find.byType(EvSessionRow))
          .toList();
      expect(rows.map((row) => row.title), [
        'Game 7',
        'Game 6',
        'Game 5',
        'Game 4',
        'Game 3',
        'Game 2',
      ]);
      expect(rows.every((row) => row.subtitle.contains('2')), isTrue);
      final (harness, _) = await show(tester, [
        game('Recent', played: DateTime(2026, 9, 8)),
      ]);
      await tester.tap(find.byType(EvSessionRow));
      await tester.pump();
      expect(harness.nav.state.openedGameId, 'Recent');
    },
  );

  testWidgets(
    'полоса карточки обновляется по задаче, а общий выключатель гасит эффекты',
    (tester) async {
      final value = game(
        'Download',
        status: GameStatus.downloading,
      ).copyWith(download: const DownloadLink(downloadTaskId: 'task'));
      final (harness, _) = await show(tester, [value]);
      for (final completed in [37, 62]) {
        harness.downloads.add(
          EngineTasksChanged([
            DownloadTask(
              id: 'task',
              name: 'torrent',
              state: DownloadState.active,
              totalBytes: 100,
              completedBytes: completed,
            ),
          ]),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<EvGameCard>(find.byType(EvGameCard)).progress,
          completed / 100,
        );
      }
      harness.settings.add(
        SettingsPatched(
          (settings) => settings.withAppearance(
            (appearance) => appearance.copyWith(libraryEffects: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FoilCard>(find.byType(FoilCard)).enabled, isFalse);
    },
  );

  testWidgets(
    'стрелки выбирают карточку, Enter открывает, дальний фокус прокручивает полку',
    (tester) async {
      final games = [
        for (var i = 0; i < 20; i++)
          game('Game ${i.toString().padLeft(2, '0')}'),
      ];
      final (harness, controller) = await show(tester, games);
      controller.requestFocus(games.first.id);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(harness.nav.state.selectedGameId, games[1].id);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(harness.nav.state.openedGameId, games[1].id);
      controller.requestFocus(games.last.id);
      await tester.pumpAndSettle();
      final card = find.byWidgetPredicate(
        (widget) => widget is EvLibraryCard && widget.game.id == games.last.id,
      );
      final rect = tester.getRect(card);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(1280));
      expect(harness.nav.state.selectedGameId, games.last.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('стрелки вверх и вниз переходят между полками', (tester) async {
    final (harness, controller) = await show(tester, [
      game('Installed', status: GameStatus.installed),
      game('Incoming'),
    ]);
    controller.requestFocus('Installed');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(harness.nav.state.selectedGameId, 'Incoming');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(harness.nav.state.selectedGameId, 'Installed');
  });

  testWidgets('низкое окно скрывает Продолжить, сохраняя карточки', (
    tester,
  ) async {
    await show(tester, [game('Recent', played: DateTime(2026, 9, 8))]);
    expect(find.byType(EvSessionRow), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pumpAndSettle();
    expect(find.byType(EvSessionRow), findsNothing);
    expect(find.byType(EvLibraryCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
