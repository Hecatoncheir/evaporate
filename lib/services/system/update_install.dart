import 'dart:io';

import 'package:path/path.dart' as p;

/// Куда приложение поставлено и чем его заменять.
///
/// На всех трёх системах приложение — это **папка**: `.app` на macOS,
/// каталог `bundle` на Linux, папка с `.exe` и библиотеками на Windows.
/// Значит установка обновления везде одна и та же работа: заменить папку A
/// папкой B. Различие ровно одно, и оно в том, **когда** это можно сделать:
/// Windows не даёт трогать файлы работающего процесса.
///
/// Поэтому замену делает не приложение, а короткий скрипт-помощник: он ждёт,
/// пока процесс умрёт, меняет папки местами и запускает приложение заново.
/// Одна схема на три системы вместо трёх разных.
class InstallLayout {
  const InstallLayout({required this.root, required this.executable});

  /// Папка, которую предстоит заменить.
  final String root;

  /// Чем запускать приложение после замены.
  final String executable;

  /// Где лежит запущенное приложение.
  ///
  /// На macOS `resolvedExecutable` указывает внутрь бандла
  /// (`…/Evaporate.app/Contents/MacOS/evaporate`), а заменять надо бандл
  /// целиком — поднимаемся до него. На остальных системах папка приложения
  /// — та, где лежит исполняемый файл.
  static InstallLayout? current({String? executablePath, String? platform}) {
    final executable = executablePath ?? Platform.resolvedExecutable;
    final os = platform ?? Platform.operatingSystem;

    // Разделитель берём по системе, а не по той, на которой считаем: путь
    // Windows на macOS иначе разбирается как одно длинное имя.
    final path = os == 'windows' ? p.windows : p.posix;

    if (os == 'macos') {
      final bundle = _bundleOf(executable, path);
      if (bundle == null) return null;
      return InstallLayout(root: bundle, executable: executable);
    }
    return InstallLayout(
      root: path.dirname(executable),
      executable: executable,
    );
  }

  /// Путь до `.app`, внутри которого лежит исполняемый файл.
  static String? _bundleOf(String executable, p.Context path) {
    var dir = path.dirname(executable);
    while (dir != path.dirname(dir)) {
      if (path.extension(dir) == '.app') return dir;
      dir = path.dirname(dir);
    }
    return null;
  }

  /// Можно ли вообще ставить обновление сюда.
  ///
  /// На Linux приложение нередко лежит в системной папке, куда его положил
  /// пакетный менеджер: писать туда нельзя, да и не нужно — обновлять такое
  /// должен тот же менеджер. Молчать об этом нельзя, но и предлагать
  /// обновление, которое не встанет, — тоже.
  Future<bool> get isWritable async {
    final probe = File(p.join(root, '.evaporate-write-probe'));
    try {
      await probe.writeAsString('1', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// Скрипт, который заменяет установку, пока приложение уже не работает.
///
/// Пишется на языке системы — `cmd` на Windows, `sh` на остальных: тащить
/// ради тридцати строк ещё одну зависимость незачем, а эти есть везде.
///
/// Порядок шагов важен и одинаков везде:
///
/// 1. дождаться, пока процесс приложения исчезнет;
/// 2. отодвинуть текущую папку в сторону, а не удалить;
/// 3. поставить новую на её место;
/// 4. запустить приложение;
/// 5. и только теперь убрать отодвинутое.
///
/// Шаг второй и пятый — это возможность откатиться. Если замена сорвётся
/// на середине, прежняя установка ещё лежит рядом и её возвращают на место;
/// если всё прошло, она уже никому не нужна.
class UpdateScript {
  const UpdateScript._();

  /// Имя отодвинутой папки. Постоянное, чтобы её можно было найти и убрать
  /// при следующем запуске, если помощник до этого не дошёл.
  static const backupSuffix = '.evaporate-old';

  /// Собирает скрипт для этой системы.
  static String build({
    required InstallLayout layout,
    required String stagedRoot,
    required int pid,
    String? platform,
  }) {
    final os = platform ?? Platform.operatingSystem;
    final backup = '${layout.root}$backupSuffix';
    return os == 'windows'
        ? _windows(layout, stagedRoot, backup, pid)
        : _posix(layout, stagedRoot, backup, pid);
  }

  /// Имя файла скрипта — по нему же его и запускают.
  static String fileName({String? platform}) =>
      (platform ?? Platform.operatingSystem) == 'windows'
      ? 'evaporate-update.cmd'
      : 'evaporate-update.sh';

  /// Чем запускать скрипт.
  static List<String> command(String script, {String? platform}) =>
      (platform ?? Platform.operatingSystem) == 'windows'
      ? ['cmd', '/c', script]
      : ['sh', script];

  static String _posix(
    InstallLayout layout,
    String staged,
    String backup,
    int pid,
  ) =>
      '''
#!/bin/sh
# Помощник обновления Evaporate. Запускается приложением перед выходом и
# работает уже без него: заменить папку работающего приложения нельзя.
set -u

root='${layout.root}'
staged='$staged'
backup='$backup'
launch='${layout.executable}'

# Ждём, пока процесс исчезнет. Не вечно: если он завис, обновление всё
# равно не задача помощника, и лучше выйти, ничего не тронув.
i=0
while kill -0 $pid 2>/dev/null; do
  i=\$((i + 1))
  [ "\$i" -gt 100 ] && exit 1
  sleep 0.1
done

rm -rf "\$backup"
mv "\$root" "\$backup" || exit 1
if ! mv "\$staged" "\$root"; then
  # Новая папка не встала — возвращаем прежнюю и уходим.
  mv "\$backup" "\$root"
  exit 1
fi

"\$launch" >/dev/null 2>&1 &
rm -rf "\$backup"
''';

  static String _windows(
    InstallLayout layout,
    String staged,
    String backup,
    int pid,
  ) =>
      '''
@echo off
rem Помощник обновления Evaporate. Запускается приложением перед выходом:
rem заменить файлы работающего процесса Windows не даёт.
setlocal
set "root=${layout.root}"
set "staged=$staged"
set "backup=$backup"
set "launch=${layout.executable}"

rem Ждём, пока процесс исчезнет, но не дольше десяти секунд.
set /a tries=0
:wait
tasklist /fi "PID eq $pid" 2>nul | find "$pid" >nul
if errorlevel 1 goto ready
set /a tries+=1
if %tries% gtr 100 exit /b 1
ping -n 1 -w 100 127.0.0.1 >nul
goto wait

:ready
if exist "%backup%" rmdir /s /q "%backup%"
move "%root%" "%backup%" || exit /b 1
move "%staged%" "%root%"
if errorlevel 1 (
  rem Новая папка не встала — возвращаем прежнюю и уходим.
  move "%backup%" "%root%"
  exit /b 1
)

start "" "%launch%"
rmdir /s /q "%backup%"
''';
}
