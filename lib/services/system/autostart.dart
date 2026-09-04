import 'dart:io';

import 'package:path/path.dart' as p;

/// Запуск приложения вместе с системой.
///
/// Отдельной зависимости здесь не нужно: на всех трёх системах это запись
/// одного файла или ключа реестра. Своя реализация к тому же проверяется
/// тестами, а поведение чужого пакета пришлось бы принимать на веру.
///
/// Источник правды — сама система, а не наши настройки: пользователь мог
/// убрать автозапуск средствами системы, и переспорить его мы не должны.
class Autostart {
  Autostart({
    String? executablePath,
    String? homeDir,
    Map<String, String>? environment,
    Future<ProcessResult> Function(String, List<String>)? run,
    String? operatingSystem,
  }) : _executable = executablePath ?? Platform.resolvedExecutable,
       _environment = environment ?? Platform.environment,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _run = run ?? Process.run {
    _home = homeDir ?? _environment[_isWindows ? 'USERPROFILE' : 'HOME'];
  }

  final String _executable;
  final Map<String, String> _environment;
  final String _operatingSystem;
  bool get _isWindows => _operatingSystem == 'windows';
  bool get _isMacOS => _operatingSystem == 'macos';
  final Future<ProcessResult> Function(String, List<String>) _run;
  late final String? _home;

  /// Имя записи одинаково на всех системах: по нему её и находим.
  static const entryName = 'Evaporate';

  static const _bundleId = 'dev.evaporate.launcher';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  /// Путь, который система будет запускать.
  ///
  /// На macOS исполняемый файл лежит внутри `.app`, и запускать нужно сам
  /// бандл: иначе приложение стартует без значка в доке и без прав, которые
  /// система выдаёт по бандлу.
  String get target {
    if (!_isMacOS) return _executable;
    final marker = '.app${p.separator}Contents${p.separator}MacOS';
    final index = _executable.indexOf(marker);
    if (index < 0) return _executable;
    return _executable.substring(0, index + 4);
  }

  /// Файл, которым автозапуск описан. На Windows записи в файле нет.
  String? get entryFile {
    final home = _home;
    if (home == null || _isWindows) return null;
    if (_isMacOS) {
      return p.join(home, 'Library', 'LaunchAgents', '$_bundleId.plist');
    }
    final config = _environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    return p.join(config, 'autostart', 'evaporate.desktop');
  }

  /// Команды реестра собраны отдельно: проверить их можно на любой
  /// системе, а выполнить — только на Windows.
  static List<String> queryArgs() => ['query', _runKey, '/v', entryName];

  /// Путь берётся в кавычки: в «Program Files» есть пробел, и без них
  /// система прочитает значение до первого пробела.
  static List<String> addArgs(String target) => [
    'add',
    _runKey,
    '/v',
    entryName,
    '/t',
    'REG_SZ',
    '/d',
    '"$target"',
    '/f',
  ];

  static List<String> removeArgs() => [
    'delete',
    _runKey,
    '/v',
    entryName,
    '/f',
  ];

  Future<bool> isEnabled() async {
    if (_isWindows) {
      final result = await _run('reg', queryArgs());
      return result.exitCode == 0;
    }
    final file = entryFile;
    if (file == null) return false;
    return File(file).exists();
  }

  Future<void> setEnabled(bool value) => value ? _enable() : _disable();

  Future<void> _enable() async {
    if (_isWindows) {
      await _runRegistry(addArgs(target));
      return;
    }

    final file = entryFile;
    if (file == null) return;
    await Directory(p.dirname(file)).create(recursive: true);
    await File(file)
        .writeAsString(_isMacOS ? macPlist(target) : desktopEntry(target));
  }

  Future<void> _disable() async {
    if (_isWindows) {
      // Удалять уже отсутствующую запись не нужно: reg delete считает
      // это ошибкой, а повторное выключение должно быть безопасным.
      if (await isEnabled()) await _runRegistry(removeArgs());
      return;
    }
    final file = entryFile;
    if (file == null) return;
    final handle = File(file);
    if (await handle.exists()) await handle.delete();
  }

  Future<void> _runRegistry(List<String> args) async {
    final result = await _run('reg', args);
    if (result.exitCode != 0) {
      throw ProcessException('reg', args, '${result.stderr}', result.exitCode);
    }
  }

  /// Задание launchd. `RunAtLoad` и есть «запускать при входе».
  static String macPlist(String target) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_bundleId</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$target</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';

  /// Запись автозапуска по спецификации XDG.
  static String desktopEntry(String target) =>
      '''
[Desktop Entry]
Type=Application
Name=$entryName
Exec="$target"
Terminal=false
X-GNOME-Autostart-enabled=true
''';
}
