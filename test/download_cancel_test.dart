import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
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
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

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
    const task = DownloadTask(
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
      find.text(l.cancelDownloadQuestion),
      findsOneWidget,
      reason: 'снятие задачи не делают по одному нажатию',
    );

    // «Оставить», а не «Отмена»: рядом стоит «Отменить», и две клавиши,
    // читающиеся одинаково, — худший вид вопроса.
    expect(find.text(l.cancel), findsNothing);
    expect(find.text(l.keepDownload), findsOneWidget);
    // И «Отменить» рядом с «Удалить совсем вместе с файлами» тоже нет:
    // два ответа читаются парой, от меньшего к большему.
    expect(find.widgetWithText(FilledButton, 'Удалить'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Отменить'), findsNothing);

    // Передумали — и ничего не случилось.
    await tester.tap(find.text(l.keepDownload));
    await tester.pumpAndSettle();
    expect(find.text(l.cancelDownloadQuestion), findsNothing);
  });

  testWidgets('скачавшей задаче предлагают стереть файлы, пустой — нет', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pump();

    Future<void> open(DownloadTask task) async {
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
                body: TaskCard(
                  task: task,
                  game: Game(
                    id: 'g1',
                    title: 'Игра',
                    addedAt: DateTime.now(),
                    status: GameStatus.downloading,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Отменить'));
      await tester.pumpAndSettle();
    }

    await open(
      const DownloadTask(
        id: 't1',
        name: 'Что-то скачано',
        state: DownloadState.active,
        totalBytes: 1000,
        completedBytes: 400,
      ),
    );
    expect(find.text(l.cancelWithFiles), findsOneWidget);
    // У каждого ответа свой значок: слова у них похожи, и глазу нужна
    // зацепка помимо чтения.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    await tester.tap(find.text(l.keepDownload));
    await tester.pumpAndSettle();

    // Задаче, не скачавшей ни байта, стирать нечего — и предлагать нечего.
    await open(
      const DownloadTask(
        id: 't2',
        name: 'Ещё не начата',
        state: DownloadState.waiting,
        totalBytes: 1000,
      ),
    );
    expect(find.text(l.cancelWithFiles), findsNothing);
    expect(find.text(l.cancelDownloadQuestion), findsOneWidget);
  });

  // Клавиша та же и делает то же самое, а очередь — не черновик, человек её
  // выстраивал. Текст, однако, свой: тут ничего не качается прямо сейчас.
  testWidgets('удаление из очереди спрашивает своими словами', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pump();

    const task = DownloadTask(
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
                queued: const [task],
                library: LibraryState(games: [game]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Убрать из очереди'));
    await tester.pumpAndSettle();

    expect(find.text(l.removeFromQueueQuestion), findsOneWidget);
    expect(
      find.text(l.cancelDownloadQuestion),
      findsNothing,
      reason: 'в очереди ничего не качается — и спрашивать надо не об этом',
    );
  });
}
