import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_log.dart';
import 'update_download.dart';
import 'update_install.dart';

/// Ставит подготовленное обновление.
///
/// Сам ничего не заменяет: пишет скрипт-помощник, запускает его отдельным
/// процессом и оставляет приложению закрыться. Заменить папку работающего
/// приложения нельзя — на Windows система не даст, на остальных это просто
/// опасно.
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
  }) : _layout = layout ?? InstallLayout.current(),
       _start = start ?? _detached,
       _pid = processId ?? pid;

  /// Куда класть скрипт — папка данных приложения. Не рядом с установкой:
  /// её вот-вот заменят.
  final String workDir;

  final InstallLayout? _layout;
  final Future<Process> Function(String, List<String>) _start;
  final int _pid;

  InstallLayout? get layout => _layout;

  /// Можно ли предложить обновление здесь и сейчас.
  ///
  /// На Linux приложение нередко лежит там, куда его положил пакетный
  /// менеджер: писать туда нельзя, да и обновлять должен он же.
  Future<bool> get canInstall async {
    final target = _layout;
    if (target == null) return false;
    return target.isWritable;
  }

  /// Запускает замену и возвращает управление: дальше приложение должно
  /// закрыться само, иначе помощник будет ждать его до упора.
  Future<void> apply(String stagedRoot) async {
    final target = _layout;
    if (target == null) {
      throw const UpdateException('Не понять, куда поставлено приложение');
    }
    if (!await target.isWritable) {
      throw const UpdateException(
        'В папку приложения нельзя писать. Обновите тем способом, каким '
        'ставили.',
      );
    }

    final script = File(p.join(workDir, UpdateScript.fileName()));
    await script.parent.create(recursive: true);
    await script.writeAsString(
      UpdateScript.build(layout: target, stagedRoot: stagedRoot, pid: _pid),
      flush: true,
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', script.path]);
    }

    AppLog.instance.write('обновление: запускаю замену из $stagedRoot');
    final command = UpdateScript.command(script.path);
    await _start(command.first, command.sublist(1));
  }

  /// Отдельным процессом и без привязки к нашему: он обязан пережить наш
  /// выход, ради этого всё и затевается.
  static Future<Process> _detached(String executable, List<String> arguments) =>
      Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
