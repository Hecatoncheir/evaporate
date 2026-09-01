import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/game.dart';

class LaunchException implements Exception {
  LaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RunningGame {
  RunningGame({
    required this.gameId,
    required this.startedAt,
    required this.process,
  });

  final String gameId;
  final DateTime startedAt;
  final Process process;

  Duration get elapsed => DateTime.now().difference(startedAt);
}

/// Запускает игру и считает наигранное время.
///
/// Время фиксируется по факту завершения процесса — именно этот момент
/// нужен и для автоснимка сохранений.
class GameLauncher {
  final Map<String, RunningGame> _running = {};
  final _runningIds = ValueNotifier<Set<String>>({});

  ValueListenable<Set<String>> get runningIds => _runningIds;

  bool isRunning(String gameId) => _running.containsKey(gameId);

  Duration? elapsedFor(String gameId) => _running[gameId]?.elapsed;

  /// [onExit] вызывается после выхода из игры: там обновляется playtime
  /// и снимается автоснапшот сейвов.
  Future<void> launch(
    Game game, {
    required void Function(Game game, Duration played, int exitCode) onExit,
  }) async {
    if (_running.containsKey(game.id)) {
      throw LaunchException('«${game.title}» уже запущена');
    }
    final exePath = game.executablePath;
    if (exePath == null || exePath.isEmpty) {
      throw LaunchException('Не указан исполняемый файл');
    }

    final isMacApp = Platform.isMacOS && exePath.endsWith('.app');
    if (isMacApp) {
      if (!await Directory(exePath).exists()) {
        throw LaunchException('Приложение не найдено: $exePath');
      }
    } else {
      final file = File(exePath);
      if (!await file.exists()) {
        throw LaunchException('Файл не найден: $exePath');
      }
      if (!Platform.isWindows) await _ensureExecutable(exePath);
    }

    final workingDir =
        game.installDir ?? (isMacApp ? p.dirname(exePath) : p.dirname(exePath));

    late final Process process;
    try {
      if (isMacApp) {
        // -W ждём выхода, -n новый экземпляр; аргументы игре — после --args.
        process = await Process.start('open', [
          '-W',
          '-n',
          '-a',
          exePath,
          if (game.launchArgs.isNotEmpty) '--args',
          ...game.launchArgs,
        ], workingDirectory: workingDir);
      } else {
        process = await Process.start(
          exePath,
          game.launchArgs,
          workingDirectory: workingDir,
        );
      }
    } on ProcessException catch (error) {
      throw LaunchException('Не удалось запустить: ${error.message}');
    }

    final running = RunningGame(
      gameId: game.id,
      startedAt: DateTime.now(),
      process: process,
    );
    _running[game.id] = running;
    _publish();

    unawaited(
      process.exitCode.then((code) {
        final played = running.elapsed;
        _running.remove(game.id);
        _publish();
        onExit(game, played, code);
      }),
    );
  }

  Future<void> terminate(String gameId) async {
    final running = _running[gameId];
    if (running == null) return;
    running.process.kill();
  }

  Future<void> _ensureExecutable(String path) async {
    try {
      final stat = await File(path).stat();
      if (stat.mode & 0x49 != 0) return;
      await Process.run('chmod', ['+x', path]);
    } on Object {
      // Не смогли — Process.start ниже сам сообщит об ошибке.
    }
  }

  void _publish() {
    _runningIds.value = _running.keys.toSet();
  }

  void dispose() {
    _runningIds.dispose();
  }
}
