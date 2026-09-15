import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/downloads/download_activity.dart';
import 'package:evaporate/ui/library/detail/action_panel.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/animated_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Открывает страницу установленной игры, которой есть чем запускаться:
  /// без исполняемого файла половины клавиш на ней не бывает.
  Future<TestHarness> openGame(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    final id = harness.addGame(
      title: 'Тестовая игра',
      installDir: '/tmp/game',
      status: GameStatus.installed,
    );
    await harness.pump(tester);
    harness.library.add(
      GameUpdated(
        harness.library.state
            .gameById(id)!
            .copyWith(executablePath: '/tmp/game/game.exe'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Тестовая игра').first);
    await tester.pumpAndSettle();
    return harness;
  }

  // Слева — то, что делают с самой игрой, справа — то, что делают с её
  // ярлыком в Steam. Между ними распорка, иначе правая половина ездила бы
  // вслед за длиной подписи главной клавиши.
  testWidgets('действия Steam стоят справа от «Играть», в одном ряду', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openGame(tester);

    final play = tester.getRect(find.text('Играть'));
    final add = tester.getRect(find.text('Добавить в Steam'));
    final lookup = tester.getRect(find.text('Найти в Steam'));
    final panel = tester.getRect(find.byType(ActionPanel));

    expect(add.left, greaterThan(play.right));
    expect(lookup.left, greaterThan(add.right));
    for (final rect in [add, lookup]) {
      expect(
        (rect.center.dy - play.center.dy).abs(),
        lessThan(4),
        reason: 'клавиши Steam должны стоять в одном ряду с «Играть»',
      );
    }

    // Прижаты к правому краю панели, а не болтаются посередине.
    expect(panel.right - lookup.right, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('папка игры ушла из ряда действий в «Подробности»', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openGame(tester);

    expect(
      find.descendant(
        of: find.byType(ActionPanel),
        matching: find.text('Папка игры'),
      ),
      findsNothing,
    );

    // Но со страницы не пропала: её место — среди сведений об игре.
    final play = tester.getRect(find.text('Играть'));
    final folder = tester.getRect(find.text('Папка игры'));
    expect(folder.top, greaterThan(play.bottom));
  });

  // Подписи у клавиш Steam длинные, и в узком окне два слова рядом с
  // «Играть» переполняли бы ряд полосатой лентой поверх интерфейса.
  testWidgets('в узком окне ряд действий переносится, а не переполняется', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(620, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openGame(tester);

    expect(find.text('Играть'), findsOneWidget);
    expect(find.text('Добавить в Steam'), findsOneWidget);
    expect(find.text('Найти в Steam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Ярлык на несуществующий файл Steam примет молча, а человек найдёт его
  // сломанным. Поиск в каталоге при этом нужен и такой игре — обложку ей
  // искать не по чему другому.
  testWidgets('игре без исполняемого файла «Добавить в Steam» не предлагают', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(
      title: 'Без файла',
      installDir: '/tmp/game',
      status: GameStatus.installed,
    );
    await harness.pump(tester);
    await tester.tap(find.text('Без файла').first);
    await tester.pumpAndSettle();

    expect(find.text('Добавить в Steam'), findsNothing);
    expect(find.text('Найти в Steam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // На странице игры спрашивают «как идёт вот эта игра». Отсылать за
  // ответом на соседний экран — значит заставлять держать в голове два
  // места; тем более что график там уже нарисован.
  testWidgets(
    'под заголовком игры виден тот же живой график, что на загрузках',
    (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      await tester.pump();

      const task = DownloadTask(
        id: 't1',
        name: 'Качается',
        state: DownloadState.active,
        totalBytes: 1000,
        completedBytes: 400,
        connections: 7,
        // Скорость задаёт и «осталось»: etaSeconds считается из неё.
        downloadSpeed: 5,
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: harness.settings),
            BlocProvider<LibraryBloc>.value(value: harness.library),
            BlocProvider<DownloadsBloc>.value(value: harness.downloads),
          ],
          child: MaterialApp(
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            locale: const Locale('ru'),
            theme: EvaporateTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: DownloadHistoryScope(
                  task: task,
                  child: ActionPanel(
                    game: Game(
                      id: 'g1',
                      title: 'Качается',
                      addedAt: DateTime.now(),
                      status: GameStatus.downloading,
                    ),
                    task: task,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DownloadActivity), findsOneWidget);
      // График сюда не входит: он уехал подложкой под заголовок страницы.
      expect(find.byType(DownloadChart), findsNothing);
      // Полоса ровно одна: две подряд заставили бы человека честно
      // выяснять, чем они различаются.
      expect(find.byType(AnimatedProgress), findsOneWidget);
      // А то, чего у графика нет, осталось: сколько ждать и с кем обмен.
      expect(find.textContaining('осталось'), findsOneWidget);
    },
  );
}
