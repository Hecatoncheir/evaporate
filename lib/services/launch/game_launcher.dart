import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/game.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

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
  GameLauncher({L Function()? localizations})
    : _localizations = localizations ?? _defaultLocalizations;

  /// Откуда брать переводы. Сообщения отсюда доходят до пользователя через
  /// уведомления, поэтому язык им нужен, а `BuildContext` взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  final Map<String, RunningGame> _running = {};
  final _runningIds = ValueNotifier<Set<String>>({});
  bool _disposed = false;

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
      throw LaunchException(_l.launchAlreadyRunning(game.title));
    }
    final exePath = game.executablePath;
    if (exePath == null || exePath.isEmpty) {
      throw LaunchException(_l.launchNoExecutable);
    }

    final isMacApp = Platform.isMacOS && exePath.endsWith('.app');
    if (isMacApp) {
      if (!await Directory(exePath).exists()) {
        throw LaunchException(_l.launchAppMissing(exePath));
      }
    } else {
      final file = File(exePath);
      if (!await file.exists()) {
        throw LaunchException(_l.launchFileMissing(exePath));
      }
      if (!Platform.isWindows) await _ensureExecutable(exePath);
    }

    final workingDir = game.installDir ?? p.dirname(exePath);

    late final Process process;
    try {
      if (isMacApp) {
        // Запускаем бинарник бандла напрямую: `open -W` даёт PID обёртки,
        // поэтому кнопка Stop завершала `open`, а игра оставалась.
        process = await Process.start(
          await _macAppExecutable(exePath),
          game.launchArgs,
          workingDirectory: workingDir,
        );
      } else {
        process = await Process.start(
          exePath,
          game.launchArgs,
          workingDirectory: workingDir,
        );
      }
    } on ProcessException catch (error) {
      throw LaunchException(_l.launchFailed(error.message));
    }

    // Необработанные pipe заполняются после нескольких десятков килобайт,
    // и тогда игра блокируется на очередной записи в stdout/stderr.
    unawaited(process.stdout.drain<void>().catchError((_) {}));
    unawaited(process.stderr.drain<void>().catchError((_) {}));

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
        if (_disposed) return;
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

  Future<String> _macAppExecutable(String appPath) async {
    final contents = p.join(appPath, 'Contents');
    final plist = p.join(contents, 'Info.plist');
    try {
      final result = await Process.run('/usr/libexec/PlistBuddy', [
        '-c',
        'Print :CFBundleExecutable',
        plist,
      ]);
      if (result.exitCode == 0) {
        final name = '${result.stdout}'.trim();
        if (name.isNotEmpty) {
          final executable = p.join(contents, 'MacOS', name);
          if (await File(executable).exists()) return executable;
        }
      }
    } on Object {
      // Ниже остаётся стандартное имя бандла.
    }

    final fallback = p.join(
      contents,
      'MacOS',
      p.basenameWithoutExtension(appPath),
    );
    if (await File(fallback).exists()) return fallback;
    throw LaunchException(_l.launchFileMissing(fallback));
  }

  void _publish() {
    _runningIds.value = _running.keys.toSet();
  }

  void dispose() {
    _disposed = true;
    _runningIds.dispose();
  }
}
