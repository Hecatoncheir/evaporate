import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/game_roots.dart';
import 'package:evaporate/services/launch/library_scanner.dart';
import 'package:evaporate/services/launch/scan_session.dart';
import 'package:evaporate/ui/library/library_page.dart';
import 'package:evaporate/ui/library/scan_folder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

/// Добавление по одной терпимо для трёх игр и мучительно для сорока —
/// ради этого диалог и существует.
///
/// Поиск начинается сразу, ещё до того, как человек что-то выберет, поэтому
/// окно показывает ход, умеет останавливаться, не выбрасывая найденное, и
/// предлагает сузить себя брошенной или выбранной папкой.
void main() {
  late Directory tmp;
  late Directory root;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
    root = Directory(p.join(tmp.path, 'games'));
    await root.create(recursive: true);
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Готовит дерево папок настоящими файловыми операциями.
  ///
  /// Через `runAsync`: внутри `testWidgets` файловый ввод-вывод живёт в
  /// фейковом времени и не завершается никогда.
  Future<T> prepare<T>(WidgetTester tester, Future<T> Function() build) async {
    late T result;
    await tester.runAsync(() async => result = await build());
    return result;
  }

  /// Папка с исполняемым файлом внутри — то, что сканер считает игрой.
  Future<Directory> gameDir(String name) async {
    final dir = Directory(p.join(root.path, name));
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, Platform.isWindows ? 'game.exe' : 'game'),
    );
    await file.writeAsString('не настоящая игра, но исполняемый файл');
    if (!Platform.isWindows) await Process.run('chmod', ['+x', file.path]);
    return dir;
  }

  Future<Directory> plainDir(String name) async {
    final dir = Directory(p.join(root.path, name));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'readme.txt')).writeAsString('ничего важного');
    return dir;
  }

  ScanSession sessionFor(TestHarness harness) => ScanSession(
    existingDirs: LibraryScanner.installedDirs(harness.library.state.games),
    steamRoots: const [],
    fixedRoots: [GameRoot(path: root.path, kind: GameRootKind.games)],
  );

  /// Открывает окно поиска и запускает обход.
  ///
  /// Диалог и обход стартуют **внутри** `runAsync`: файловые операции
  /// настоящие, а начатые в фейковом времени теста они не сдвинутся с места.
  Future<ScanSession> startScan(
    WidgetTester tester,
    TestHarness harness,
  ) async {
    final session = sessionFor(harness);
    addTearDown(session.dispose);
    final context = tester.element(find.byType(LibraryPage));

    await tester.runAsync(() async {
      unawaited(showScanFolderDialog(context, session));
      unawaited(session.scanKnownRoots());
      await tester.pump();
    });
    await tester.pump();
    return session;
  }

  /// Ждёт конца обхода — **снаружи** `runAsync`: кадры внутри него в цикле
  /// не идут. По условию, а не паузой: на машине сборки обход занимает
  /// другое время.
  Future<void> waitForScan(WidgetTester tester, ScanSession session) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (session.isRunning) {
      if (DateTime.now().isAfter(deadline)) fail('обход папок не закончился');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  /// Пустая библиотека с законченным обходом на экране.
  Future<TestHarness> openScan(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    final session = await startScan(tester, harness);
    await waitForScan(tester, session);
    return harness;
  }

  /// Нажатие «Добавить» вместе с отложенной записью библиотеки на диск.
  Future<void> addChosen(WidgetTester tester, int count) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить: $count'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('найденные игры показываются и отмечены заранее', (tester) async {
    await prepare(tester, () => gameDir('Тихая гавань'));
    await prepare(tester, () => gameDir('Долгая дорога'));
    await prepare(tester, () => plainDir('Просто папка'));

    await openScan(tester);

    expect(find.text('Тихая гавань'), findsOneWidget);
    expect(find.text('Долгая дорога'), findsOneWidget);
    // Папка без исполняемого файла игрой не считается.
    expect(find.text('Просто папка'), findsNothing);
    // Пришли добавлять, а не отсеивать: отмечено всё.
    expect(find.widgetWithText(FilledButton, 'Добавить: 2'), findsOneWidget);
  });

  testWidgets('отмеченные игры уходят в библиотеку установленными', (
    tester,
  ) async {
    final dir = await prepare(tester, () => gameDir('Тихая гавань'));

    final harness = await openScan(tester);
    await addChosen(tester, 1);

    expect(find.byType(AlertDialog), findsNothing);
    final game = harness.library.state.games.single;
    expect(game.title, 'Тихая гавань');
    expect(game.status, GameStatus.installed);
    expect(game.installDir, dir.path);
    expect(game.source?.kind, GameSourceKind.localFolder);
    expect(game.executablePath, isNotNull);
  });

  testWidgets('снятая галочка исключает игру из добавления', (tester) async {
    await prepare(tester, () => gameDir('Нужная'));
    await prepare(tester, () => gameDir('Лишняя'));

    final harness = await openScan(tester);
    await tester.tap(
      find.ancestor(
        of: find.text('Лишняя'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    await tester.pumpAndSettle();

    await addChosen(tester, 1);

    expect(harness.library.state.games.single.title, 'Нужная');
  });

  // Кнопка без отметок добавила бы ноль игр и закрыла диалог — вид работы
  // вместо работы.
  testWidgets('без единой отметки добавлять нечем', (tester) async {
    await prepare(tester, () => gameDir('Единственная'));

    await openScan(tester);
    await tester.tap(
      find.ancestor(
        of: find.text('Единственная'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Добавить: 0'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('пустая папка честно говорит, что игр нет', (tester) async {
    await prepare(tester, () => plainDir('Ничего похожего'));

    await openScan(tester);

    expect(find.textContaining('Ничего не нашлось'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Добавить: 0'), findsOneWidget);
  });

  // Повторный поиск не должен предлагать добавить то, что уже добавлено:
  // библиотека обросла бы дублями.
  testWidgets('уже добавленную папку второй раз не предлагают', (tester) async {
    final dir = await prepare(tester, () => gameDir('Уже в библиотеке'));
    await prepare(tester, () => gameDir('Ещё не добавлена'));

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(
      title: 'Уже в библиотеке',
      installDir: dir.path,
      status: GameStatus.installed,
    );
    await harness.pump(tester);

    final session = await startScan(tester, harness);
    await waitForScan(tester, session);

    expect(find.widgetWithText(FilledButton, 'Добавить: 1'), findsOneWidget);
    expect(find.text('Ещё не добавлена'), findsOneWidget);
  });

  testWidgets('отмена закрывает окно, ничего не добавив', (tester) async {
    await prepare(tester, () => gameDir('Передумали'));

    final harness = await openScan(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.library.state.games, isEmpty);
  });

  // Окно с одной вертушкой ничем не отличается от зависшего: пока идёт
  // обход, человек должен видеть, на чём приложение стоит, и уметь его
  // прервать.
  testWidgets('пока идёт поиск, видны ход и кнопка остановки', (tester) async {
    await prepare(tester, () => gameDir('Медленная'));

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await startScan(tester, harness);

    expect(find.widgetWithText(TextButton, 'Остановить'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('по окончании поиска остановка уже не предлагается', (
    tester,
  ) async {
    await prepare(tester, () => gameDir('Найденная'));

    await openScan(tester);

    expect(find.text('Найденная'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Остановить'), findsNothing);
  });

  // Остановка — это «хватит искать», а не «забудь найденное».
  testWidgets('остановка оставляет найденное на экране', (tester) async {
    await prepare(tester, () => gameDir('Найденная'));

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    final session = await startScan(tester, harness);
    await waitForScan(tester, session);

    session.stop();
    await tester.pump();

    expect(find.text('Найденная'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Добавить: 1'), findsOneWidget);
  });

  // Системное окно выбора само не открывается: человек нажал «найти игры», а
  // не «выбери папку». Сузить поиск предлагается здесь же.
  testWidgets('в окне есть куда бросить папку и куда нажать', (tester) async {
    await prepare(tester, () => gameDir('Найденная'));

    await openScan(tester);

    expect(find.text('Бросьте сюда папку с играми'), findsOneWidget);
    expect(find.textContaining('нажмите, чтобы выбрать'), findsOneWidget);
    expect(find.byType(DropTarget), findsWidgets);
  });

  // Брошенная папка сужает поиск, а не добавляется одной игрой: для этого
  // есть сетка библиотеки, и она броски в это время не ловит.
  testWidgets('брошенная папка сужает поиск до неё', (tester) async {
    await prepare(tester, () => gameDir('Широкая'));
    final narrow = await prepare(tester, () async {
      final dir = Directory(p.join(tmp.path, 'узкая', 'Нужная'));
      await dir.create(recursive: true);
      final file = File(
        p.join(dir.path, Platform.isWindows ? 'game.exe' : 'game'),
      );
      await file.writeAsString('исполняемый');
      if (!Platform.isWindows) await Process.run('chmod', ['+x', file.path]);
      return Directory(p.join(tmp.path, 'узкая'));
    });

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    final session = await startScan(tester, harness);
    await waitForScan(tester, session);
    expect(find.text('Широкая'), findsOneWidget);

    await tester.runAsync(() async {
      unawaited(session.scanOnly(narrow.path));
      await tester.pump();
    });
    await waitForScan(tester, session);

    expect(find.text('Нужная'), findsOneWidget);
    expect(find.text('Широкая'), findsNothing);
  });
}
