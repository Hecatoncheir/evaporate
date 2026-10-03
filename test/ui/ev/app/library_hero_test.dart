import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/ev/app/ev_library_hero.dart';
import 'package:evaporate/ui/ev/library/ev_hero.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_app.dart';

void main() {
  final l = LRu();
  final game = Game(
    id: 'hero',
    title: 'Hollow.Knight.v1.5.78-GOG',
    addedAt: DateTime(2026),
    status: GameStatus.installed,
    executablePath: 'game.exe',
  );
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(
    WidgetTester tester,
    Game value, {
    VoidCallback? onPrimary,
    VoidCallback? onOpen,
    Locale? locale,
  }) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      harness.buildApp(
        locale: locale,
        builder: (context, child) => Center(
          child: EvLibraryHero(
            game: value,
            onOpen: onOpen ?? () {},
            onPrimary: onPrimary ?? () {},
            sweepEnabled: false,
            shotsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets(
    'короткое нажатие не запускает игру, удержание запускает один раз',
    (tester) async {
      var launches = 0;
      await show(tester, game, onPrimary: () => launches++);
      expect(tester.widget<EvHero>(find.byType(EvHero)).title, 'Hollow Knight');
      final button = find.byType(EvPlayButton);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 700));
      expect(launches, 0);
      final press = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 619));
      expect(launches, 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(launches, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(launches, 1);
      await press.up();
    },
  );

  for (final (status, label) in [
    (GameStatus.running, l.stop),
    (GameStatus.downloading, l.pause),
    (GameStatus.paused, l.resume),
  ]) {
    testWidgets('$status: действие срабатывает сразу', (tester) async {
      var actions = 0;
      await show(
        tester,
        game.copyWith(status: status),
        onPrimary: () => actions++,
      );
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.byType(EvPlayButton));
      await tester.pump();
      expect(actions, 1);
    });
  }

  testWidgets(
    'прогресс приходит от связанной задачи, меняется без смены игры',
    (tester) async {
      final harness = await show(
        tester,
        game.copyWith(
          status: GameStatus.downloading,
          download: const DownloadLink(downloadTaskId: 'task'),
        ),
      );
      harness.downloads.add(
        const EngineTasksChanged([
          DownloadTask(
            id: 'task',
            name: 'torrent',
            state: DownloadState.active,
            totalBytes: 100,
            completedBytes: 37,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('37 %'), findsOneWidget);
      expect(tester.widget<EvBar>(find.byType(EvBar)).value, .37);
      harness.downloads.add(
        const EngineTasksChanged([
          DownloadTask(
            id: 'task',
            name: 'torrent',
            state: DownloadState.paused,
            totalBytes: 100,
            completedBytes: 62,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('62 %'), findsOneWidget);
    },
  );

  testWidgets('погашенный запуск не срабатывает, сведения доступны', (
    tester,
  ) async {
    var launches = 0;
    var opens = 0;
    await show(
      tester,
      game.copyWith(executablePath: null),
      onPrimary: () => launches++,
      onOpen: () => opens++,
    );
    expect(find.text(l.featuredNoExecutable), findsOneWidget);
    expect(
      tester.widget<EvPlayButton>(find.byType(EvPlayButton)).onLaunch,
      isNull,
    );
    await tester.tap(find.text(l.openGame));
    await tester.pump();
    expect(opens, 1);
    expect(launches, 0);
  });

  testWidgets('подключённый кадр не показывает строки образцовой игры', (
    tester,
  ) async {
    await show(tester, game, locale: const Locale('en'));
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('HOLD'), findsOneWidget);
    expect(find.text(l.play), findsNothing);
    expect(find.textContaining('Глава'), findsNothing);
    expect(find.text('Оверлей'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
