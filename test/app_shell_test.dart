import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  late Directory tmp;

  // Папка готовится снаружи теста: реальный файловый I/O внутри
  // testWidgets не завершается — там фейковое время.
  setUp(() async => tmp = await TestHarness.makeTempDir());

  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('пустая библиотека объясняет, что делать дальше', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.text('Библиотека пуста'), findsOneWidget);
    expect(find.text('Добавить игру'), findsWidgets);
  });

  testWidgets('переключение разделов не ломает оболочку', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    await tester.tap(find.text('Загрузки'));
    await tester.pumpAndSettle();
    expect(find.text('Сейчас скачивается'), findsOneWidget);
    expect(find.text('Дальше в очереди'), findsOneWidget);

    await tester.tap(find.text('Сохранения'));
    await tester.pumpAndSettle();
    expect(find.text('Папка синхронизации'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Папка для игр'), findsOneWidget);
    expect(find.text('Управление'), findsOneWidget);

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
    expect(find.text('Папки сохранений'), findsOneWidget);
    expect(find.text('Снимки сохранений'), findsOneWidget);
    expect(find.text('Файлы игры'), findsOneWidget);
    // Без указанного исполняемого файла «Играть» должна быть недоступна.
    final playButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Играть'),
    );
    expect(playButton.onPressed, isNull);
  });

  testWidgets('строка состояния сообщает, что движок не запущен', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    expect(find.textContaining('Движок загрузок'), findsOneWidget);
  });

  testWidgets('подсказки управления видны в нижней строке', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await harness.pump(tester);

    // Геймпад не подключён — показываем клавиатурные подсказки.
    expect(find.text('Навигация'), findsOneWidget);
    expect(find.text('Выбрать'), findsOneWidget);
  });

  testWidgets('на карточке качающейся игры виден процент', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    final id = harness.addGame(title: 'Качается');
    await harness.pump(tester);

    // Привязываем игру к задаче движка и подаём прогресс 42%.
    final game = harness.library.state.gameById(id)!;
    harness.library.add(
      GameUpdated(
        game.copyWith(status: GameStatus.downloading, downloadGid: 'gid-1'),
      ),
    );
    harness.downloads.add(
      const EngineTasksChanged([
        DownloadTask(
          id: 'gid-1',
          name: 'раздача',
          state: DownloadState.active,
          totalBytes: 1000,
          completedBytes: 420,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('42%'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
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

    for (final section in ['Загрузки', 'Сохранения', 'Настройки']) {
      await tester.tap(find.text(section).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'раздел «$section»');
    }
  });
}
