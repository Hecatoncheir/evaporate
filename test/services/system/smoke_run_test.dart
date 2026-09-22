import 'dart:async';
import 'dart:io';

import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/services/system/smoke_run.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// `--smoke` отвечает прогону кодом выхода, и ответ этот должен быть
/// честным: ноль — только когда приложение дошло до кадра, записало файл и
/// завершилось, оставив журнал.
void main() {
  late SmokeRun smoke;
  late String dataDir;
  late String logFile;
  final lines = <String>[];

  setUp(() async {
    smoke = await SmokeRun.prepare();
    dataDir = p.join(smoke.home.path, 'data');
    logFile = p.join(dataDir, 'evaporate.log');
    await Directory(dataDir).create(recursive: true);
    lines.clear();
  });

  tearDown(() => deleteTempDir(smoke.home));

  Future<void> writeLog() => File(logFile).writeAsString('запуск\n');

  Future<int> check({
    Future<void>? firstFrame,
    Future<void> Function()? shutdown,
  }) => smoke.check(
    firstFrame: firstFrame ?? Future<void>.value(),
    shutdown: shutdown ?? writeLog,
    dataDir: dataDir,
    logFile: logFile,
    timeout: const Duration(milliseconds: 200),
    report: lines.add,
  );

  test('флаг узнаётся среди аргументов', () {
    expect(SmokeRun.requested(['--smoke']), isTrue);
    expect(SmokeRun.requested(['--other', '--smoke']), isTrue);
    expect(SmokeRun.requested([]), isFalse);
  });

  test('дошедший до конца запуск отвечает нулём и убирает свой дом', () async {
    expect(await check(), 0);

    expect(lines, hasLength(3));
    expect(smoke.home.existsSync(), isFalse);
  });

  test('не дождались первого кадра — провал, а не вечное ожидание', () async {
    expect(await check(firstFrame: Completer<void>().future), 1);
    expect(lines.last, contains('провал'));
  });

  // Отказ трея приложение переживает, показывая окно, — и по окну его не
  // видно. А без значка свёрнутое при запуске приложение не открыть.
  test('не вставший значок в трее — провал', () async {
    final code = await smoke.check(
      firstFrame: Future<void>.value(),
      shutdown: writeLog,
      dataDir: dataDir,
      logFile: logFile,
      trayShown: () => false,
      report: lines.add,
    );

    expect(code, 1);
    expect(lines.last, contains('трее'));
  });

  test('сорвавшееся завершение — провал', () async {
    expect(await check(shutdown: () async => throw StateError('шаг')), 1);
  });

  // Журнал — единственный способ узнать о сбое у человека: запуск, после
  // которого его нет, проверки не прошёл.
  test('без журнала после завершения — провал', () async {
    expect(await check(shutdown: () async {}), 1);
    expect(lines.last, contains('журнал'));
  });

  test('свой дом — свои каталоги, мимо системных', () async {
    final paths = await AppPaths.init(home: smoke.home.path);

    expect(p.isWithin(smoke.home.path, paths.dataDir), isTrue);
    expect(p.isWithin(smoke.home.path, paths.defaultInstallDir), isTrue);
    expect(Directory(paths.savesDir).existsSync(), isTrue);
  });
}
