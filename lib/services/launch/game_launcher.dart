import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
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
  GameLauncher({
    L Function()? localizations,
    this.terminateGrace = const Duration(seconds: 5),
  }) : _localizations = localizations ?? _defaultLocalizations;

  /// Сколько ждать вежливого завершения, прежде чем убивать.
  ///
  /// Укорачивается в тестах: проверять эскалацию настоящими пятью секундами
  /// на каждом прогоне — плата ни за что.
  final Duration terminateGrace;

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
    // Место занимаем синхронно, до первого ожидания: между проверкой и
    // регистрацией процесса идут проверки файла и сам запуск, и второе
    // нажатие проходило проверку тоже. Выход первого процесса стирал
    // тогда запись второго.
    if (_running.containsKey(game.id) || !_starting.add(game.id)) {
      throw LaunchException(_l.launchAlreadyRunning(game.title));
    }
    try {
      await _start(game, onExit: onExit);
    } finally {
      _starting.remove(game.id);
    }
  }

  /// Игры, запуск которых начат и ещё не закончен.
  final _starting = <String>{};

  Future<void> _start(
    Game game, {
    required void Function(Game game, Duration played, int exitCode) onExit,
  }) async {
    final executable = await _resolveExecutable(game);
    final workingDir = game.installDir ?? p.dirname(game.executablePath!);

    final Process process;
    try {
      process = await Process.start(
        executable,
        game.launchArgs,
        workingDirectory: workingDir,
      );
    } on ProcessException catch (error) {
      throw LaunchException(_l.launchFailed(error.message));
    }

    _track(game, process, onExit: onExit);
  }

  /// Что именно запускать — и все отказы разом.
  ///
  /// Развилка по системе стоит здесь одна: у бандла macOS запускается
  /// бинарник внутри, потому что `open -W` отдаёт PID обёртки, и кнопка
  /// «Стоп» закрывала её, а игра оставалась.
  Future<String> _resolveExecutable(Game game) async {
    final exePath = game.executablePath;
    if (exePath == null || exePath.isEmpty) {
      throw LaunchException(_l.launchNoExecutable);
    }

    if (Platform.isMacOS && exePath.endsWith('.app')) {
      if (!await Directory(exePath).exists()) {
        throw LaunchException(_l.launchAppMissing(exePath));
      }
      return _macAppExecutable(exePath);
    }

    if (!await File(exePath).exists()) {
      throw LaunchException(_l.launchFileMissing(exePath));
    }
    if (!Platform.isWindows) await _ensureExecutable(exePath);
    return exePath;
  }

  /// Берёт запущенный процесс под присмотр.
  void _track(
    Game game,
    Process process, {
    required void Function(Game game, Duration played, int exitCode) onExit,
  }) {
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

  /// Закрывает игру.
  ///
  /// Сначала обычный сигнал завершения, а если процесс на него не ответил —
  /// принудительный. Игры игнорируют `SIGTERM` сплошь и рядом: у них свой
  /// цикл событий, и сигнал в нём попросту некому обработать. Без второго
  /// шага кнопка «Стоп» выглядела бы сломанной, а игра оставалась бы висеть
  /// вместе со своим полноэкранным окном.
  Future<void> terminate(String gameId) async {
    final running = _running[gameId];
    if (running == null) return;
    running.process.kill();

    // Ждём по факту завершения, а не отмеренной паузой: обычно процесс
    // уходит сразу, и держать кнопку занятой лишние секунды незачем.
    try {
      await running.process.exitCode.timeout(terminateGrace);
      return;
    } on TimeoutException {
      // Не ответил — значит, вежливость исчерпана.
    }
    if (_running.containsKey(gameId)) {
      running.process.kill(ProcessSignal.sigkill);
    }
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
