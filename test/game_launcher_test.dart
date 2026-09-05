import 'dart:async';
import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/game_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late GameLauncher launcher;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_launch_');
    launcher = GameLauncher();
  });

  tearDown(() async {
    launcher.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Скрипт вместо игры: запускается так же, как обычный исполняемый файл.
  Future<String> makeScript(String body, {bool executable = true}) async {
    final file = File(p.join(tmp.path, 'game.sh'));
    await file.writeAsString('#!/bin/sh\n$body\n');
    if (executable) await Process.run('chmod', ['+x', file.path]);
    return file.path;
  }

  Game gameWith(String? executablePath) => Game(
    id: 'game-1',
    title: 'Тестовая',
    addedAt: DateTime.now(),
    installDir: tmp.path,
    executablePath: executablePath,
  );

  test('без указанного файла запускать нечего', () async {
    await expectLater(
      launcher.launch(gameWith(null), onExit: (_, _, _) {}),
      throwsA(isA<LaunchException>()),
    );
  });

  test('несуществующий файл даёт понятную ошибку', () async {
    await expectLater(
      launcher.launch(
        gameWith(p.join(tmp.path, 'нет-такого')),
        onExit: (_, _, _) {},
      ),
      throwsA(isA<LaunchException>()),
    );
  });

  test('процесс запускается, а его завершение доходит до колбэка', () async {
    final path = await makeScript('exit 0');
    final exited = Completer<int>();

    await launcher.launch(
      gameWith(path),
      onExit: (game, played, code) => exited.complete(code),
    );

    expect(await exited.future.timeout(const Duration(seconds: 10)), 0);
    expect(launcher.isRunning('game-1'), isFalse);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('код возврата игры передаётся как есть', () async {
    final path = await makeScript('exit 3');
    final exited = Completer<int>();

    await launcher.launch(
      gameWith(path),
      onExit: (game, played, code) => exited.complete(code),
    );

    expect(await exited.future.timeout(const Duration(seconds: 10)), 3);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('большой stdout и stderr не блокируют завершение', () async {
    final path = await makeScript(
      'i=0; while [ \$i -lt 20000 ]; do '
      'echo "строка \$i"; echo "ошибка \$i" >&2; i=\$((i+1)); done',
    );
    final exited = Completer<int>();

    await launcher.launch(
      gameWith(path),
      onExit: (_, _, code) => exited.complete(code),
    );

    expect(await exited.future.timeout(const Duration(seconds: 10)), 0);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('пока игра идёт, она числится запущенной', () async {
    final path = await makeScript('sleep 5');
    final exited = Completer<void>();

    await launcher.launch(
      gameWith(path),
      onExit: (_, _, _) => exited.complete(),
    );

    expect(launcher.isRunning('game-1'), isTrue);
    expect(launcher.runningIds.value, contains('game-1'));
    expect(launcher.elapsedFor('game-1'), isNotNull);

    await launcher.terminate('game-1');
    await exited.future.timeout(const Duration(seconds: 10));

    expect(launcher.isRunning('game-1'), isFalse);
    expect(launcher.runningIds.value, isEmpty);
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('дважды одну игру не запустить', () async {
    final path = await makeScript('sleep 5');
    final exited = Completer<void>();
    await launcher.launch(
      gameWith(path),
      onExit: (_, _, _) => exited.complete(),
    );

    await expectLater(
      launcher.launch(gameWith(path), onExit: (_, _, _) {}),
      throwsA(isA<LaunchException>()),
    );

    await launcher.terminate('game-1');
    await exited.future.timeout(const Duration(seconds: 10));
  }, skip: Platform.isWindows ? 'скрипт sh не запустится на Windows' : null);

  test('остановка незапущенной игры ничего не ломает', () async {
    await launcher.terminate('нет-такой-игры');
  });

  // Игры игнорируют SIGTERM сплошь и рядом: обрабатывать его в их цикле
  // событий некому. Без принудительного сигнала «Стоп» ничего не делал бы.
  //
  // Скрипт `sh` здесь не годится: на macOS он умирает от SIGTERM и с
  // `trap`, то есть проверял бы не то. Нужен процесс, который сигнал
  // действительно игнорирует, — отсюда python3 и пропуск без него.
  test(
    'игра, не отвечающая на обычный сигнал, всё равно закрывается',
    () async {
      final stubborn = GameLauncher(
        terminateGrace: const Duration(milliseconds: 200),
      );
      addTearDown(stubborn.dispose);
      final ready = File(p.join(tmp.path, 'ready'));
      final file = File(p.join(tmp.path, 'stubborn.sh'));
      // Метка появляется, когда обработчик сигнала уже стоит. Без неё
      // SIGTERM успевал прилететь в саму оболочку, пока она ещё не
      // сменилась на python, — и тест проверял бы смерть оболочки.
      await file.writeAsString(
        '#!/bin/sh\n'
        'exec python3 -c "import signal, sys, time; '
        'signal.signal(signal.SIGTERM, signal.SIG_IGN); '
        "open(sys.argv[1], 'w').close(); time.sleep(30)\" '${ready.path}'\n",
      );
      await Process.run('chmod', ['+x', file.path]);
      final exited = Completer<void>();

      await stubborn.launch(
        gameWith(file.path),
        onExit: (_, _, _) => exited.complete(),
      );
      while (!ready.existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await stubborn.terminate('game-1');
      await exited.future.timeout(const Duration(seconds: 10));

      expect(stubborn.isRunning('game-1'), isFalse);
    },
    skip: _stubbornSkip(),
  );

  test('файл без права на запуск получает его сам', () async {
    final path = await makeScript('exit 0', executable: false);
    final exited = Completer<int>();

    await launcher.launch(
      gameWith(path),
      onExit: (game, played, code) => exited.complete(code),
    );

    expect(await exited.future.timeout(const Duration(seconds: 10)), 0);
  }, skip: Platform.isWindows ? 'права доступа устроены иначе' : null);

  test('macOS bundle запускает и останавливает настоящий бинарник', () async {
    final app = Directory(p.join(tmp.path, 'TestGame.app'));
    final executable = File(
      p.join(app.path, 'Contents', 'MacOS', 'CustomExecutable'),
    );
    await executable.parent.create(recursive: true);
    await executable.writeAsString('#!/bin/sh\nsleep 30\n');
    await Process.run('chmod', ['+x', executable.path]);
    await File(p.join(app.path, 'Contents', 'Info.plist')).writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CustomExecutable</string>
</dict></plist>
''');
    final exited = Completer<void>();

    await launcher.launch(
      gameWith(app.path),
      onExit: (_, _, _) => exited.complete(),
    );
    expect(launcher.isRunning('game-1'), isTrue);

    await launcher.terminate('game-1');
    await exited.future.timeout(const Duration(seconds: 10));

    expect(launcher.isRunning('game-1'), isFalse);
  }, skip: Platform.isMacOS ? null : 'проверка формата macOS .app');
}

/// Процесс, по-настоящему игнорирующий SIGTERM, нужен именно настоящий —
/// иначе тест проверял бы не эскалацию, а поведение оболочки. На Windows
/// скрипт не запустится вовсе, без python3 такой процесс не из чего собрать.
String? _stubbornSkip() {
  if (Platform.isWindows) return 'скрипт sh не запустится на Windows';
  final found = Process.runSync('sh', ['-c', 'command -v python3']);
  return found.exitCode == 0 ? null : 'нужен python3';
}
