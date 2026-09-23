import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_log.dart';
import 'update_download.dart';
import 'update_install.dart';

/// Ставит подготовленное обновление.
///
/// На Windows запускает Inno Setup напрямую отсоединённым процессом.
/// На macOS и Linux пишет и запускает POSIX-помощник, который заменит папку
/// после выхода приложения.
///
/// Отсюда единственная неприятная особенность, о которой надо предупредить,
/// а не делать молча: приложение закроется и откроется заново.
class UpdateInstaller {
  UpdateInstaller({
    required this.workDir,
    InstallLayout? layout,
    @visibleForTesting
    Future<Process> Function(String executable, List<String> arguments)? start,
    @visibleForTesting int? processId,
    @visibleForTesting String? platform,
    AppLog Function()? log,
  }) : _layout = layout ?? InstallLayout.current(),
       _start = start ?? _detached,
       _pid = processId ?? pid,
       _os = platform ?? Platform.operatingSystem,
       _log = log ?? _appLog;

  /// Куда класть файлы обновления и журнал.
  final String workDir;

  /// Куда помощник пишет о себе.
  ///
  /// Работает он уже без приложения, и рассказать о случившемся ему больше
  /// нечем: при следующем запуске приложение забирает написанное в свой
  /// журнал. Без этого отказ выглядел так — окно закрылось, не открылось, и
  /// ни следа почему.
  static String logPath(String workDir) =>
      p.join(workDir, 'evaporate-update.log');

  /// Куда о себе пишет установщик Windows.
  static String setupLogPath(String workDir) =>
      p.join(workDir, 'evaporate-update-setup.log');

  /// Куда писать о ходе замены.
  ///
  /// Функцией, а не готовым журналом, по той же причине, что и `L
  /// Function()` у блоков: журнал заводится в `main` и к моменту сборки
  /// сервиса может быть ещё не тем, каким станет. А в тестах он
  /// подменяется без правки глобала — иначе одна забытая перестановка
  /// обратно тянула бы записи чужих тестов в свой файл.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;

  final InstallLayout? _layout;
  final Future<Process> Function(String, List<String>) _start;
  final int _pid;
  final String _os;

  static const windowsSetupArguments = [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/SP-',
    '/CLOSEAPPLICATIONS',
    '/RELAUNCH',
  ];

  InstallLayout? get layout => _layout;

  /// Можно ли предложить обновление здесь и сейчас.
  ///
  /// На Windows обновляем только копию, поставленную Inno Setup:
  /// portable-zip лучше не превращать в установленную копию без спроса.
  /// На Linux приложение нередко лежит там, куда его положил пакетный
  /// менеджер: писать туда нельзя, да и обновлять должен он же. А
  /// записываемость не говорит, чья папка: распакованная прямо в
  /// «Загрузки» сборка делает папкой приложения сами «Загрузки», и замена
  /// унесла бы их целиком. Поэтому на Linux нужна ещё и метка сборки
  /// (`InstallLayout.isOwnFolder`); бандл macOS свой по устройству.
  Future<bool> get canInstall async {
    final target = _layout;
    if (target == null) return false;
    if (_os == 'windows') {
      return File(p.join(target.root, 'unins000.exe')).exists();
    }
    if (_os == 'linux' && !await target.isOwnFolder) return false;
    return target.isWritable;
  }

  /// Запускает setup или POSIX-замену и возвращает управление. Дальше
  /// приложение должно закрыться.
  Future<void> apply(String stagedRoot) async {
    final target = _layout;
    if (target == null) {
      throw const UpdateException(UpdateFailure.unknownLayout);
    }
    if (!await canInstall) {
      throw const UpdateException(UpdateFailure.notUpdatable);
    }

    if (_os == 'windows') {
      if (p.extension(stagedRoot).toLowerCase() != '.exe') {
        throw const UpdateException(UpdateFailure.noWindowsSetup);
      }
      _log().write('обновление: запускаю setup $stagedRoot');
      // Свой номер процесса передаём затем, чтобы установщик дождался
      // нашего выхода: файлы работающего приложения Windows заменить не
      // даёт, а закрыться раньше его запуска мы не можем — запускать
      // установщик было бы уже некому.
      await _start(stagedRoot, [
        ...windowsSetupArguments,
        '/WAITPID=$_pid',
        '/LOG=${setupLogPath(workDir)}',
      ]);
      return;
    }

    final script = File(p.join(workDir, UpdateScript.fileName));
    await script.parent.create(recursive: true);
    await script.writeAsString(
      UpdateScript.build(
        layout: target,
        stagedRoot: stagedRoot,
        pid: _pid,
        logPath: logPath(workDir),
      ),
      flush: true,
    );
    if (_os != 'windows') {
      await Process.run('chmod', ['+x', script.path]);
    }

    _log().write('обновление: запускаю замену из $stagedRoot');
    final command = UpdateScript.command(script.path);
    await _start(command.first, command.sublist(1));
  }

  /// Забирает записи помощника в журнал приложения и убирает его файл.
  ///
  /// Помощник работает, когда приложения уже нет, поэтому написать в общий
  /// журнал сам он не может — пишет в свой, а мы переносим при следующем
  /// запуске. Иначе о неудавшейся замене не узнал бы никто: человек видел бы
  /// только прежнюю версию и гадал.
  static Future<void> collectLog(String workDir, {AppLog? log}) async {
    final journal = log ?? AppLog.instance;
    final file = File(logPath(workDir));
    try {
      // Проверка на месте, а не выходом из метода: журнал помощника и
      // журнал установщика — разные файлы, и отсутствие первого не
      // повод не забрать второй.
      if (await file.exists()) {
        for (final line in (await file.readAsString()).split('\n')) {
          if (line.trim().isNotEmpty) journal.write(line.trim());
        }
        await file.delete();
      }
    } on Object {
      // Записи помощника — не то, ради чего стоит ронять запуск.
    }
    await _collectSetupLog(workDir, journal);
  }

  /// Забирает из журнала установщика Windows то, ради чего его просили
  /// писать.
  ///
  /// Целиком он не нужен — это сотни строк о каждом файле. Нужны строки об
  /// отказе: без них неудавшееся обновление выглядело так — окно
  /// закрылось, новая версия не появилась, и ни следа почему.
  static Future<void> _collectSetupLog(String workDir, AppLog journal) async {
    final file = File(setupLogPath(workDir));
    try {
      if (!await file.exists()) return;
      final failures = (await file.readAsLines()).where(_looksLikeFailure);
      for (final line in failures.take(_setupLogLimit)) {
        journal.write('обновление: ${line.trim()}');
      }
      await file.delete();
    } on Object {
      // Журнал установщика — не то, ради чего стоит ронять запуск.
    }
  }

  /// Сколько строк об отказе забирать: дальше первого десятка это уже не
  /// диагноз, а поток — установщик повторяет одно и то же о каждом файле.
  static const _setupLogLimit = 10;

  /// Похожа ли строка на сообщение об отказе.
  ///
  /// Язык журнала — системный, поэтому слова берём на обоих: у одного
  /// человека там `Setup aborted`, у другого «Установка прервана».
  static bool _looksLikeFailure(String line) {
    const markers = [
      'aborted',
      'exception',
      'denied',
      'cannot',
      'failed',
      'error',
      'прерван',
      'отказ',
      'ошибк',
      'не удалось',
    ];
    final lower = line.toLowerCase();
    return markers.any(lower.contains);
  }

  /// Отдельным процессом и без привязки к нашему: он обязан пережить наш
  /// выход, ради этого всё и затевается.
  static Future<Process> _detached(String executable, List<String> arguments) =>
      Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
