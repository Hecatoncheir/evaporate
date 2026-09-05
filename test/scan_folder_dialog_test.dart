import 'dart:async';
import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/library_page.dart';
import 'package:evaporate/ui/library/scan_folder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

/// Добавление по одной терпимо для трёх игр и мучительно для сорока —
/// ради этого диалог и существует.
void main() {
  late Directory tmp;
  late Directory root;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
    root = Directory(p.join(tmp.path, 'games'));
    await root.create(recursive: true);
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

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

  /// Готовит дерево папок настоящими файловыми операциями.
  ///
  /// Через `runAsync`, а не напрямую: внутри `testWidgets` файловый
  /// ввод-вывод живёт в фейковом времени и не завершается никогда — тест
  /// висел бы до самого таймаута, ничего не сообщая.
  Future<T> prepare<T>(WidgetTester tester, Future<T> Function() build) async {
    late T result;
    await tester.runAsync(() async => result = await build());
    return result;
  }

  /// Открывает диалог и дожидается конца обхода папок.
  ///
  /// Две тонкости, и обе стоили висящего теста. Диалог открывается **внутри**
  /// `runAsync`: обход папок настоящий, а начатый в фейковом времени теста он
  /// не сдвинется с места, сколько потом ни прокручивай кадры. А вот ждать
  /// его приходится **снаружи**: кадры внутри `runAsync` в цикле не идут.
  ///
  /// Ждём по условию, а не отмеренной паузой: на загруженной машине сборки
  /// обход укладывается в другое время, чем здесь.
  Future<void> runScan(WidgetTester tester) async {
    final context = tester.element(find.byType(LibraryPage));
    await tester.runAsync(() async {
      unawaited(showScanFolderDialog(context, root.path));
      await tester.pump();
    });

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('обход папок не закончился');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Пустая библиотека с показанными результатами обхода.
  Future<TestHarness> openScan(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await runScan(tester);
    return harness;
  }

  /// Нажатие «Добавить» вместе с отложенной записью библиотеки на диск:
  /// без неё в конце теста остаётся висеть таймер.
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

  // Повторное сканирование той же папки не должно предлагать добавить то,
  // что уже добавлено: библиотека обросла бы дублями.
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
    await runScan(tester);

    expect(find.widgetWithText(FilledButton, 'Добавить: 1'), findsOneWidget);
    expect(find.text('Ещё не добавлена'), findsOneWidget);
  });

  testWidgets('отмена закрывает диалог, ничего не добавив', (tester) async {
    await prepare(tester, () => gameDir('Передумали'));

    final harness = await openScan(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.library.state.games, isEmpty);
  });
}
