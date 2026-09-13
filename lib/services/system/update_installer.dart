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
  }) : _layout = layout ?? InstallLayout.current(),
       _start = start ?? _detached,
       _pid = processId ?? pid,
       _os = platform ?? Platform.operatingSystem;

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
  /// менеджер: писать туда нельзя, да и обновлять должен он же.
  Future<bool> get canInstall async {
    final target = _layout;
    if (target == null) return false;
    if (_os == 'windows') {
      return File(p.join(target.root, 'unins000.exe')).exists();
    }
    return target.isWritable;
  }

  /// Запускает setup или POSIX-замену и возвращает управление. Дальше
  /// приложение должно закрыться.
  Future<void> apply(String stagedRoot) async {
    final target = _layout;
    if (target == null) {
      throw const UpdateException('Не понять, куда поставлено приложение');
    }
    if (!await canInstall) {
      throw const UpdateException(
        'Эту копию нельзя обновить автоматически. '
        'Обновите тем способом, каким ставили.',
      );
    }

    if (_os == 'windows') {
      if (p.extension(stagedRoot).toLowerCase() != '.exe') {
        throw const UpdateException('Установщик Windows не найден');
      }
      final log = p.join(workDir, 'evaporate-update-setup.log');
      AppLog.instance.write('обновление: запускаю setup $stagedRoot');
      await _start(stagedRoot, [...windowsSetupArguments, '/LOG=$log']);
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

    AppLog.instance.write('обновление: запускаю замену из $stagedRoot');
    final command = UpdateScript.command(script.path);
    await _start(command.first, command.sublist(1));
  }

  /// Забирает записи помощника в журнал приложения и убирает его файл.
  ///
  /// Помощник работает, когда приложения уже нет, поэтому написать в общий
  /// журнал сам он не может — пишет в свой, а мы переносим при следующем
  /// запуске. Иначе о неудавшейся замене не узнал бы никто: человек видел бы
  /// только прежнюю версию и гадал.
  static Future<void> collectLog(String workDir) async {
    final file = File(logPath(workDir));
    try {
      if (!await file.exists()) return;
      for (final line in (await file.readAsString()).split('\n')) {
        if (line.trim().isNotEmpty) AppLog.instance.write(line.trim());
      }
      await file.delete();
    } on Object {
      // Записи помощника — не то, ради чего стоит ронять запуск.
    }
  }

  /// Отдельным процессом и без привязки к нашему: он обязан пережить наш
  /// выход, ради этого всё и затевается.
  static Future<Process> _detached(String executable, List<String> arguments) =>
      Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
