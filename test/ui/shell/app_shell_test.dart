import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/animated_progress.dart';
import 'package:evaporate/ui/widgets/launcher_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  late Directory tmp;

  // Папка готовится снаружи теста: реальный файловый I/O внутри
  // testWidgets не завершается — там фейковое время.
  setUp(() async => tmp = await TestHarness.makeTempDir());

  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('пустая библиотека объясняет, что делать дальше', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.text(l.libraryEmpty), findsOneWidget);
    expect(find.text(l.addGame), findsWidgets);
  });

  testWidgets('переключение разделов не ломает оболочку', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    await tester.tap(find.text('ЗАГРУЗКИ').first);
    await tester.pumpAndSettle();
    expect(find.text('СЕЙЧАС СКАЧИВАЕТСЯ'), findsOneWidget);
    expect(find.text('ДАЛЬШЕ В ОЧЕРЕДИ'), findsOneWidget);

    await tester.tap(find.text('СОХРАНЕНИЯ').first);
    await tester.pumpAndSettle();
    expect(find.text(l.syncFolder), findsOneWidget);

    await tester.tap(find.text('НАСТРОЙКИ').first);
    await tester.pumpAndSettle();
    expect(find.text(l.appearanceAndLanguage), findsOneWidget);
    expect(find.text(l.controls), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('карточка игры показывает статус и блоки сохранений', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    harness.addGame(
      title: 'Тестовая игра',
      source: const GameSource(
        kind: GameSourceKind.localFolder,
        value: '/tmp/game',
      ),
      installDir: '/tmp/game',
      status: GameStatus.installed,
    );

    await harness.pump(tester);

    // В сетке игра — плитка; страница с блоками открывается нажатием.
    expect(find.text('Тестовая игра'), findsOneWidget);
    await tester.tap(find.text('Тестовая игра'));
    await tester.pumpAndSettle();

    expect(find.text('Тестовая игра'), findsWidgets);
    expect(find.text(l.savePaths), findsOneWidget);
    expect(find.text(l.snapshots), findsOneWidget);
    expect(find.text(l.gameFiles), findsOneWidget);
    // Без указанного исполняемого файла «Играть» должна быть недоступна.
    final playButton = tester.widget<LauncherActionButton>(
      find.widgetWithText(LauncherActionButton, 'Играть'),
    );
    expect(playButton.onPressed, isNull);
  });

  // Раздачу, которую человек принёс сам, он вправе унести обратно —
  // а у игры из локальной папки уносить нечего.
  testWidgets('кнопка выгрузки .torrent есть только у раздачи', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    harness.addGame(
      title: 'Из папки',
      source: const GameSource(
        kind: GameSourceKind.localFolder,
        value: '/tmp/game',
      ),
      installDir: '/tmp/game',
      status: GameStatus.installed,
    );
    harness.addGame(
      title: 'Из раздачи',
      source: const GameSource(
        kind: GameSourceKind.magnet,
        value: 'magnet:?xt=urn:btih:0123',
      ),
      installDir: '/tmp/game',
      status: GameStatus.installed,
    );
    await harness.pump(tester);

    await tester.tap(find.text('Из папки'));
    await tester.pumpAndSettle();
    expect(find.text(l.exportTorrent), findsNothing);

    await tester.tap(find.text(l.backToLibrary));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Из раздачи'));
    await tester.pumpAndSettle();
    expect(find.text(l.exportTorrent), findsOneWidget);
  });

  testWidgets('экран загрузок сообщает, что движок не запущен', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);
    harness.nav.add(const SectionSelected(AppSection.downloads));
    await tester.pumpAndSettle();

    expect(find.textContaining('Движок загрузок'), findsOneWidget);
  });

  testWidgets('подсказки управления видны в нижней строке', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    // Геймпад не подключён — показываем клавиатурные подсказки.
    expect(find.text(l.hintNavigate), findsOneWidget);
    expect(find.text('Выбрать'), findsOneWidget);
  });

  testWidgets('на карточке качающейся игры виден процент', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    final id = harness.addGame(title: 'Качается');
    await harness.pump(tester);

    // Привязываем игру к задаче движка и подаём прогресс 42%.
    harness.library.add(
      GameDownloadStarted(
        id,
        const GameSource(
          kind: GameSourceKind.magnet,
          value: 'magnet:?xt=urn:btih:test',
        ),
        'task-1',
      ),
    );
    harness.downloads.add(
      const EngineTasksChanged([
        DownloadTask(
          id: 'task-1',
          name: 'раздача',
          state: DownloadState.active,
          totalBytes: 1000,
          completedBytes: 420,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('42%'), findsWidgets);
    expect(find.byType(AnimatedProgress), findsWidgets);
    // Reduced-motion tests can settle before the persistence debounce.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('поиск фильтрует список игр', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    harness.addGame(title: 'Первая');
    harness.addGame(title: 'Вторая');

    await harness.pump(tester);
    expect(find.text('Первая'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Втор');
    await tester.pumpAndSettle();

    expect(find.text('Первая'), findsNothing);
    expect(find.text('Вторая'), findsWidgets);
  });

  // Светлая тема появилась позже тёмной, и легко забыть перевести на палитру
  // один-два экрана. Здесь оболочка целиком строится в обеих: вшитый цвет
  // сам по себе тест не завалит, но упавшая вёрстка или потерянный контекст —
  // да, а обход всех разделов задевает почти весь интерфейс.
  testWidgets('оболочка строится в светлой теме', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester, theme: EvaporateTheme.light());

    for (final section in ['ЗАГРУЗКИ', 'СОХРАНЕНИЯ', 'НАСТРОЙКИ']) {
      await tester.tap(find.text(section).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'раздел «$section»');
    }
  });

  testWidgets('узкое окно уплотняет аппаратную панель без переполнения', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(820, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    // Подписи — деталь полноразмерной панели; в узком окне место важнее,
    // но все четыре раздела остаются доступны скринридеру.
    for (final section in [
      'Библиотека',
      'Загрузки',
      'Сохранения',
      'Настройки',
    ]) {
      expect(find.bySemanticsLabel(section), findsOneWidget);
    }

    // И остаются в верхней рейке: прежде обойма переезжала под содержимое
    // и налезала на подсказки управления в нижней строке.
    final rack = tester.getRect(find.byKey(const ValueKey('navigation-rack')));
    expect(
      rack.bottom,
      lessThan(80),
      reason: 'разделы должны остаться в рейке, а не уехать вниз',
    );
    expect(tester.takeException(), isNull);
  });

  // Место в рейке обойма уступает по очереди: сначала подписи, потом число
  // задач, и лишь затем сжимает сами клавиши. Ширина, заданная числом,
  // переполняла рейку на считанные точки — ровно те, из-за которых Flutter
  // рисует полосатую ленту поверх интерфейса.
  testWidgets('в совсем узком окне разделы прячут подписи, но не названия', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(620, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.text('БИБЛИОТЕКА'), findsNothing);
    for (final section in [
      'Библиотека',
      'Загрузки',
      'Сохранения',
      'Настройки',
    ]) {
      expect(find.bySemanticsLabel(section), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
