import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evaporate/services/system/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Второй экземпляр над теми же файлами — два движка над одними раздачами и
/// уборка одного, стирающая снимки другого: защита хранилища живёт в памяти
/// одного процесса. Проверяется настоящим вторым процессом — на macOS и
/// Linux замок файла принадлежит процессу, и захват из того же проходит.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_instance_');
  });
  tearDown(() => deleteTempDir(tmp));

  /// Процесс, держащий замок, и его строки вывода.
  Future<(Process, StreamIterator<String>)> holder() async {
    // Прогон идёт в `flutter_tester`, а не в `dart`, и `dart` в PATH на
    // Windows — это `dart.bat`, которого без оболочки не запустить. Берём
    // сам исполняемый файл из SDK, лежащего внутри Flutter.
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ??
        p.joinAll(
          p.split(Platform.resolvedExecutable).takeWhile((s) => s != 'bin'),
        );
    final dart = p.join(
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      Platform.isWindows ? 'dart.exe' : 'dart',
    );
    final process = await Process.start(
      File(dart).existsSync() ? dart : 'dart',
      runInShell: !File(dart).existsSync(),
      [
        '--packages=${p.join('.dart_tool', 'package_config.json')}',
        p.join('test', 'support', 'single_instance_holder.dart'),
        tmp.path,
      ],
    );
    final lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    addTearDown(() async {
      process.kill();
      await process.exitCode;
    });
    return (process, lines);
  }

  Future<String> next(StreamIterator<String> lines) async {
    final moved = await lines.moveNext().timeout(const Duration(seconds: 60));
    return moved ? lines.current : '<конец вывода>';
  }

  test('второй экземпляр замка не получает и просит показать окно', () async {
    final (process, lines) = await holder();
    expect(await next(lines), 'held');

    var shown = false;
    final second = await SingleInstance.acquire(
      tmp.path,
      onShowRequested: () => shown = true,
    );

    expect(second, isNull, reason: 'два процесса над одними файлами');
    expect(await next(lines), 'show', reason: 'первый не узнал о просьбе');
    expect(shown, isFalse);
    await process.stdin.close();
  });

  test('отпущенный замок достаётся следующему', () async {
    final (process, lines) = await holder();
    expect(await next(lines), 'held');
    await process.stdin.close();
    await process.exitCode.timeout(const Duration(seconds: 30));

    final instance = await SingleInstance.acquire(
      tmp.path,
      onShowRequested: () {},
    );

    expect(instance, isNotNull);
    await instance!.release();
  });

  // Чужой процесс на машине может постучаться в порт — показать окно по
  // его слову нельзя, а упасть от него тем более.
  test('чужое сообщение в порт окно не показывает', () async {
    var shown = 0;
    final instance = await SingleInstance.acquire(
      tmp.path,
      onShowRequested: () => shown++,
    );
    addTearDown(() => instance!.release());
    final port = int.parse(
      await File(SingleInstance.portPath(tmp.path)).readAsString(),
    );

    final stranger = await Socket.connect(InternetAddress.loopbackIPv4, port);
    stranger.write('rm -rf /');
    await stranger.close();
    final friend = await Socket.connect(InternetAddress.loopbackIPv4, port);
    friend.write(SingleInstance.showRequest);
    await friend.close();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (shown == 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(shown, 1);
  });
}
