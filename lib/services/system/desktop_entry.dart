import 'dart:io';

import 'package:path/path.dart' as p;

/// Запись в меню приложений Linux.
///
/// Сборка под Linux — это папка с исполняемым файлом, а не установленный
/// пакет, поэтому в меню приложение само по себе не появляется: `.desktop`
/// его туда и добавляет.
///
/// Ставится не молча при запуске, а по кнопке: запись в общесистемное меню —
/// то, о чём пользователя стоит спросить, как и о разрешении на уведомления.
class DesktopEntry {
  DesktopEntry({
    String? executablePath,
    String? homeDir,
    Map<String, String>? environment,
  }) : _executable = executablePath ?? Platform.resolvedExecutable,
       _environment = environment ?? Platform.environment {
    _home = homeDir ?? _environment['HOME'];
  }

  final String _executable;
  final Map<String, String> _environment;
  late final String? _home;

  static const fileName = 'evaporate.desktop';

  /// Есть ли смысл предлагать это действие вообще.
  bool get isSupported => Platform.isLinux;

  /// Куда кладётся запись. Именно `~/.local/share`, а не общесистемная
  /// папка: прав администратора у нас нет и просить их незачем.
  String? get entryFile {
    final home = _home;
    if (home == null) return null;
    final dataHome =
        _environment['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
    return p.join(dataHome, 'applications', fileName);
  }

  /// Иконку сборка кладёт рядом с исполняемым файлом.
  String get iconPath => p.join(p.dirname(_executable), 'data', 'app_icon.png');

  Future<bool> isInstalled() async {
    final file = entryFile;
    if (file == null) return false;
    return File(file).exists();
  }

  Future<void> install() async {
    final file = entryFile;
    if (file == null) return;
    await Directory(p.dirname(file)).create(recursive: true);
    await File(file).writeAsString(contents(_executable, iconPath));
  }

  Future<void> remove() async {
    final file = entryFile;
    if (file == null) return;
    final handle = File(file);
    if (await handle.exists()) await handle.delete();
  }

  /// Содержимое записи по спецификации XDG.
  ///
  /// Путь берётся в кавычки: приложение может лежать в папке с пробелом,
  /// а `Exec` разбирается по словам.
  static String contents(String executable, String icon) =>
      '''
[Desktop Entry]
Type=Application
Name=Evaporate
GenericName=Game launcher
Comment=Лончер игр с переносимыми сохранениями
Exec="$executable" %U
Icon=$icon
Terminal=false
Categories=Game;
StartupWMClass=evaporate
''';
}
