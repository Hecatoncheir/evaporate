import 'dart:io';

import 'package:path/path.dart' as p;

/// Где приложение установлено и какой файл его запускает.
///
/// На macOS и Linux эти пути нужны POSIX-помощнику, который заменит
/// папку после выхода. На Windows папку обновляет Inno Setup, а layout
/// нужен для проверки, что текущая копия была установлена им.
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
/// Нужен только macOS и Linux. Windows запускает Inno Setup
/// напрямую, без промежуточного PowerShell-процесса.
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

  /// Собирает POSIX-помощник.
  static String build({
    required InstallLayout layout,
    required String stagedRoot,
    required int pid,
    required String logPath,
  }) {
    final backup = '${layout.root}$backupSuffix';
    // Пути подставляются внутрь одинарных кавычек sh, а имя
    // пользователя бывает и `D'Artagnan`.
    String quoted(String value) => value.replaceAll("'", r"'\''");

    return _posix
        .replaceAll('@ROOT@', quoted(layout.root))
        .replaceAll('@STAGED@', quoted(stagedRoot))
        .replaceAll('@BACKUP@', quoted(backup))
        .replaceAll('@LAUNCH@', quoted(layout.executable))
        .replaceAll('@LOG@', quoted(logPath))
        .replaceAll('@PID@', '$pid');
  }

  static const fileName = 'evaporate-update.sh';

  static List<String> command(String script) => ['sh', script];

  /// Помощник для macOS и Linux.
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
