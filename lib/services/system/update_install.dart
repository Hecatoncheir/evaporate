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
    required String logPath,
    String? platform,
  }) {
    final os = platform ?? Platform.operatingSystem;
    final backup = '${layout.root}$backupSuffix';
    final windows = os == 'windows';
    // Пути подставляются внутрь строк в одинарных кавычках, а имя
    // пользователя бывает и `D'Artagnan`. Экранируем по правилам языка:
    // в PowerShell апостроф удваивается, в sh — закрывает строку и
    // приписывается отдельно.
    String quoted(String value) =>
        windows ? value.replaceAll("'", "''") : value.replaceAll("'", r"'\''");

    return (windows ? _windows : _posix)
        .replaceAll('@ROOT@', quoted(layout.root))
        .replaceAll('@STAGED@', quoted(stagedRoot))
        .replaceAll('@BACKUP@', quoted(backup))
        .replaceAll('@LAUNCH@', quoted(layout.executable))
        .replaceAll('@LOG@', quoted(logPath))
        .replaceAll('@PID@', '$pid');
  }

  /// Имя файла скрипта — по нему же его и запускают.
  static String fileName({String? platform}) =>
      (platform ?? Platform.operatingSystem) == 'windows'
      ? 'evaporate-update.ps1'
      : 'evaporate-update.sh';

  /// Чем запускать скрипт.
  ///
  /// На Windows — PowerShell со скрытым окном, и это не украшательство.
  /// Помощник запускается отсоединённым процессом, то есть **без консоли**, а
  /// каждая внешняя команда в такой обстановке получает от системы
  /// собственное окно. Прежний помощник на `cmd` ждал выхода приложения
  /// циклом из `tasklist`, `find` и `ping` — по три окна на оборот, до сотни
  /// оборотов, и человек видел, как они появляются одно за другим. В
  /// PowerShell то же ожидание — один `Wait-Process`, без единого
  /// подпроцесса.
  static List<String> command(String script, {String? platform}) =>
      (platform ?? Platform.operatingSystem) == 'windows'
      ? [
          'powershell',
          '-NoProfile',
          // Скрипт свой, только что записанный рядом, но политика запуска по
          // умолчанию не даст выполнить и такой.
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script,
        ]
      : ['sh', script];

  /// Помощник для Windows.
  ///
  /// Собирается подстановкой, а не интерполяцией: в PowerShell своих
  /// `$переменных` больше, чем наших, и экранировать каждую — верный способ
  /// однажды промахнуться в строке, которую никто не компилирует.
  static const _windows = r'''
# Помощник обновления Evaporate. Запускается приложением перед выходом:
# заменить файлы работающего процесса Windows не даёт.

$root = '@ROOT@'
$staged = '@STAGED@'
$backup = '@BACKUP@'
$launch = '@LAUNCH@'
$log = '@LOG@'

# Помощник работает уже без приложения, и рассказать о себе ему больше
# нечем. Без этих строк отказ выглядел так: окно закрылось, не открылось, и
# ни следа почему.
function Note($text) {
  try {
    Add-Content -LiteralPath $log -Value "$(Get-Date -Format 'o') $text"
  } catch {}
}

Note "обновление: начинаю, папка $root"

# Ждём, пока процесс исчезнет. Тридцать секунд, а не десять: у приложения
# свой бюджет на дописывание несделанного, и уложиться в десять оно не
# обязано.
$gone = $false
for ($i = 0; $i -lt 60; $i++) {
  if (-not (Get-Process -Id @PID@ -ErrorAction SilentlyContinue)) {
    $gone = $true
    break
  }
  Start-Sleep -Milliseconds 500
}
if (-not $gone) {
  Note 'обновление: приложение не закрылось, папку не трогаю'
  exit 1
}

# Папку могут ещё держать: антивирус, индексатор, проводник. Одна попытка
# сразу после выхода — самая неудачная из возможных.
function Swap($from, $to) {
  for ($i = 0; $i -lt 20; $i++) {
    try {
      Move-Item -LiteralPath $from -Destination $to -Force -ErrorAction Stop
      return $true
    } catch {
      Start-Sleep -Milliseconds 300
    }
  }
  Note "обновление: не переместить $from -> $to"
  return $false
}

if (Test-Path -LiteralPath $backup) {
  try {
    Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop
  } catch {
    Note 'обновление: прежняя копия не убралась'
  }
}

$replaced = $false
if (Swap $root $backup) {
  if (Swap $staged $root) {
    $replaced = $true
  } else {
    Note 'обновление: новая папка не встала, возвращаю прежнюю'
    [void](Swap $backup $root)
  }
}

# Запускаем в любом случае — и после удачи, и после отката. Человек закрыл
# приложение ради обновления; остаться вовсе без него — худший исход, чем
# остаться на прежней версии.
try {
  Start-Process -FilePath $launch
} catch {
  Note 'обновление: приложение не запустилось'
}

if ($replaced) {
  Note 'обновление: установлено'
  Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
} else {
  Note 'обновление: не установлено, версия прежняя'
}
''';

  /// Помощник для macOS и Linux. Отличается от windows только языком:
  /// порядок шагов и обещание запустить приложение в любом случае — те же.
  static const _posix = r'''
#!/bin/sh
# Помощник обновления Evaporate. Запускается приложением перед выходом и
# работает уже без него: заменить папку работающего приложения нельзя.
set -u

root='@ROOT@'
staged='@STAGED@'
backup='@BACKUP@'
launch='@LAUNCH@'
log='@LOG@'

note() {
  printf '%s %s\n' "$(date +%FT%T)" "$1" >> "$log" 2>/dev/null || true
}

note "обновление: начинаю, папка $root"

# Ждём, пока процесс исчезнет. Тридцать секунд: у приложения свой бюджет на
# дописывание несделанного.
gone=0
i=0
while [ "$i" -lt 60 ]; do
  if ! kill -0 @PID@ 2>/dev/null; then
    gone=1
    break
  fi
  i=$((i + 1))
  sleep 0.5
done
if [ "$gone" -ne 1 ]; then
  note 'обновление: приложение не закрылось, папку не трогаю'
  exit 1
fi

# Папку могут ещё держать, и одна попытка сразу после выхода — самая
# неудачная из возможных.
swap() {
  j=0
  while [ "$j" -lt 20 ]; do
    if mv "$1" "$2" 2>/dev/null; then
      return 0
    fi
    j=$((j + 1))
    sleep 0.3
  done
  note "обновление: не переместить $1 -> $2"
  return 1
}

rm -rf "$backup" 2>/dev/null || true

replaced=0
if swap "$root" "$backup"; then
  if swap "$staged" "$root"; then
    replaced=1
  else
    note 'обновление: новая папка не встала, возвращаю прежнюю'
    swap "$backup" "$root" || true
  fi
fi

# Запускаем в любом случае — и после удачи, и после отката: остаться вовсе
# без приложения хуже, чем остаться на прежней версии.
"$launch" >/dev/null 2>&1 &

if [ "$replaced" -eq 1 ]; then
  note 'обновление: установлено'
  rm -rf "$backup" 2>/dev/null || true
else
  note 'обновление: не установлено, версия прежняя'
fi
''';
}
