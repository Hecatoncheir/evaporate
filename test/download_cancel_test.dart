import 'dart:io';

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/ui/downloads/queue_column.dart';
import 'package:evaporate/ui/downloads/task_card.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Отмена снимает задачу насовсем: место в очереди, обмен с пирами и
/// состояние кусков теряются, а игра уходит из «качается». Такое не делают
/// по одному нажатию — тем более что клавиша стала заметной.
void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('отмена на карточке задачи сначала спрашивает', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    final id = harness.addGame(
      title: 'Качается',
      status: GameStatus.downloading,
    );
    await tester.pump();

    final game = Game(
      id: id,
      title: 'Качается',
      addedAt: DateTime.now(),
      status: GameStatus.downloading,
    );
    final task = DownloadTask(
      id: 't1',
      name: 'Качается',
      state: DownloadState.active,
      totalBytes: 1000,
      completedBytes: 400,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: harness.settings),
          BlocProvider.value(value: harness.library),
          BlocProvider.value(value: harness.downloads),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          theme: EvaporateTheme.dark(),
          // Украшения выключены: живой график загрузки гонит кадры без
          // остановки, и `pumpAndSettle` не дождался бы покоя.
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: TaskCard(task: task, game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Отменить'));
    await tester.pumpAndSettle();

    expect(
      find.text('Отменить загрузку?'),
      findsOneWidget,
      reason: 'снятие задачи не делают по одному нажатию',
    );

    // Передумали — и ничего не случилось.
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить загрузку?'), findsNothing);
  });

  // Клавиша та же и делает то же самое, а очередь — не черновик, человек её
  // выстраивал. Текст, однако, свой: тут ничего не качается прямо сейчас.
  testWidgets('удаление из очереди спрашивает своими словами', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pump();

    final task = DownloadTask(
      id: 't1',
      name: 'Ждёт своего часа',
      state: DownloadState.waiting,
      totalBytes: 1000,
    );
    final game = Game(
      id: 'g1',
      title: 'Ждёт своего часа',
      addedAt: DateTime.now(),
      status: GameStatus.downloading,
      downloadTaskId: 't1',
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: harness.settings),
          BlocProvider.value(value: harness.library),
          BlocProvider.value(value: harness.downloads),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          theme: EvaporateTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: QueueColumn(
                active: const [],
                queued: [task],
                library: LibraryState(games: [game]),
                allTasks: [task],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Убрать из очереди'));
    await tester.pumpAndSettle();

    expect(find.text('Убрать из очереди?'), findsOneWidget);
    expect(
      find.text('Отменить загрузку?'),
      findsNothing,
      reason: 'в очереди ничего не качается — и спрашивать надо не об этом',
    );
  });
}
