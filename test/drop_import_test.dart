import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:flutter/services.dart';
import 'package:evaporate/services/launch/drop_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

/// Что происходит с тем, что перетащили в окно библиотеки.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_drop_');
  });

  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  /// Папка с игрой: имя папки станет названием, а исполняемый файл найдётся.
  Future<String> gameFolder(String name, {bool withExecutable = true}) async {
    final dir = Directory(p.join(tmp.path, name));
    await dir.create(recursive: true);
    if (withExecutable) {
      // Запускаемое определяется по-разному на разных системах: на Windows
      // это .exe, на macOS и Linux — скрипт.
      final file = Platform.isWindows ? 'game.exe' : 'game.sh';
      await File(p.join(dir.path, file)).writeAsString('#!/bin/sh');
    }
    return dir.path;
  }

  Future<String> file(String name, [String content = 'd8:announce']) async {
    final path = p.join(tmp.path, name);
    await File(path).writeAsString(content);
    return path;
  }

  test(
    'папка становится установленной игрой с названием по имени папки',
    () async {
      final dir = await gameFolder('Hollow Knight');

      final result = await DropImport.inspect([dir]);

      expect(result.single.kind, DropKind.folder);
      expect(result.single.title, 'Hollow Knight');
      expect(result.single.source.kind, GameSourceKind.localFolder);
      expect(result.single.source.value, dir);
    },
  );

  // Без этого игра добавилась бы «установленной», но не запускалась, и
  // человеку пришлось бы искать исполняемый файл руками.
  test('в сброшенной папке сразу находится, что запускать', () async {
    final dir = await gameFolder('Игра');

    final result = await DropImport.inspect([dir]);

    expect(result.single.executablePath, isNotNull);
    expect(p.dirname(result.single.executablePath!), dir);
  });

  test('папка без запускаемого всё равно добавляется', () async {
    final dir = await gameFolder('Пустая', withExecutable: false);

    final result = await DropImport.inspect([dir]);

    expect(result.single.kind, DropKind.folder);
    expect(result.single.executablePath, isNull);
  });

  test('.torrent идёт в загрузку, а название берётся без расширения', () async {
    final path = await file('Hollow Knight [RePack].torrent');

    final result = await DropImport.inspect([path]);

    expect(result.single.kind, DropKind.torrent);
    expect(result.single.title, 'Hollow Knight [RePack]');
    expect(result.single.source.kind, GameSourceKind.torrentFile);
  });

  test('расширение узнаётся в любом регистре', () async {
    final path = await file('Игра.TORRENT');

    expect((await DropImport.inspect([path])).single.kind, DropKind.torrent);
  });

  // Проглотить молча — худшее из возможного: человек ждёт игру в списке.
  test('посторонний файл помечается неподходящим, а не пропадает', () async {
    final path = await file('readme.txt', 'просто текст');

    final result = await DropImport.inspect([path]);

    expect(result, hasLength(1));
    expect(result.single.kind, DropKind.unsupported);
  });

  test('несуществующий путь неподходящий, а не ошибка', () async {
    final result = await DropImport.inspect([p.join(tmp.path, 'нет такого')]);

    expect(result.single.kind, DropKind.unsupported);
  });

  // Перетащить пачку — обычное дело, и порядок в ней пользовательский.
  test('несколько путей разбираются разом и сохраняют порядок', () async {
    final first = await gameFolder('Первая');
    final torrent = await file('Вторая.torrent');
    final junk = await file('третье.txt');

    final result = await DropImport.inspect([first, torrent, junk]);

    expect(result.map((c) => c.kind), [
      DropKind.folder,
      DropKind.torrent,
      DropKind.unsupported,
    ]);
    expect(result.map((c) => c.title), ['Первая', 'Вторая', 'третье.txt']);
  });

  test('пустой сброс — пустой разбор', () async {
    expect(await DropImport.inspect(const []), isEmpty);
  });

  // Разбор проверен выше сам по себе; здесь — что он вообще подключён:
  // событие плагина доходит до библиотеки и превращается в игру.
  group('сброс доходит до библиотеки', () {
    late Directory uiTmp;
    late String folder;

    // Папку готовим снаружи testWidgets: настоящий файловый ввод-вывод
    // внутри него не завершается.
    setUp(() async {
      uiTmp = await TestHarness.makeTempDir();
      folder = p.join(uiTmp.path, 'Сброшенная игра');
      await Directory(folder).create(recursive: true);
      final exe = Platform.isWindows ? 'game.exe' : 'game.sh';
      await File(p.join(folder, exe)).writeAsString('#!/bin/sh');
    });

    tearDown(() => TestHarness.removeTempDir(uiTmp));

    /// Подаёт событие плагина так же, как это делает система.
    Future<void> drop(WidgetTester tester, List<String> paths) async {
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Future<void> send(MethodCall call) => messenger.handlePlatformMessage(
        'desktop_drop',
        codec.encodeMethodCall(call),
        (_) {},
      );

      // Точка внутри сетки: приёмник пропускает мимо всё, что упало не в него.
      await send(const MethodCall('entered', <double>[800, 600]));
      await send(MethodCall('performOperation', paths));
    }

    testWidgets('сброшенная папка становится игрой в библиотеке', (
      tester,
    ) async {
      final harness = TestHarness(uiTmp);
      addTearDown(harness.dispose);
      await harness.pump(tester);

      // В настоящей зоне: обработчик сброса ходит на диск, а под фейковым
      // временем такие операции не завершаются.
      await tester.runAsync(() async {
        await drop(tester, [folder]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final games = harness.library.state.games;
      expect(games, hasLength(1));
      expect(games.single.title, 'Сброшенная игра');
      expect(games.single.status, GameStatus.installed);
      expect(games.single.installDir, folder);
      expect(games.single.executablePath, isNotNull);
    });

    testWidgets('посторонний файл не заводит игру', (tester) async {
      final junk = p.join(uiTmp.path, 'readme.txt');
      await tester.runAsync(() => File(junk).writeAsString('текст'));

      final harness = TestHarness(uiTmp);
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await tester.runAsync(() async {
        await drop(tester, [junk]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(harness.library.state.games, isEmpty);
    });
  });
}
