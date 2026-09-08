import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:evaporate/services/system/update_check.dart';
import 'package:evaporate/services/system/update_download.dart';
import 'package:evaporate/services/system/update_install.dart';
import 'package:evaporate/services/system/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Обновление по нажатию — единственное место, где приложение переписывает
/// само себя. Неудачная замена оставит человека без работающего
/// приложения, поэтому проверяется каждый шаг: что скачали то самое, что
/// архив не просит записать наружу и что откатиться есть куда.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_update_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Архив в том виде, в каком его кладёт сборка.
  ///
  /// Папки в нём — отдельные записи с косой чертой на конце: так их пишут и
  /// `Compress-Archive`, и `ditto`, и обычный zip.
  List<int> zipOf(Map<String, String> files, {List<String> dirs = const []}) {
    final archive = Archive();
    for (final dir in dirs) {
      archive.add(ArchiveFile.directory(dir));
    }
    files.forEach((name, content) {
      archive.add(ArchiveFile.string(name, content));
    });
    return ZipEncoder().encode(archive);
  }

  Release releaseWith({
    required String name,
    required List<int> bytes,
    bool withSums = true,
    String? sumsOverride,
  }) => Release(
    version: '9.9.9',
    url: 'https://example.invalid/release',
    assets: [
      ReleaseAsset(
        name: name,
        url: 'https://example.invalid/$name',
        sizeBytes: bytes.length,
      ),
      if (withSums)
        const ReleaseAsset(
          name: 'SHA256SUMS',
          url: 'https://example.invalid/SHA256SUMS',
          sizeBytes: 0,
        ),
    ],
  );

  /// Подделка сети: отдаёт архив и суммы, ничего никуда не отправляя.
  UpdateDownload downloadOf({
    required String name,
    required List<int> bytes,
    String? sums,
    bool sumsFail = false,
  }) => UpdateDownload(
    workDir: tmp.path,
    fetch: (uri, onProgress) async {
      if (uri.path.endsWith('SHA256SUMS')) {
        if (sumsFail) throw const SocketException('нет связи');
        return utf8.encode(sums ?? '${sha256.convert(bytes)}  $name\n');
      }
      onProgress(bytes.length, bytes.length);
      return bytes;
    },
  );

  // Имя архива для своей системы приходит из релиза, а какое оно — знает
  // сборка. Тест берёт то же, что и приложение.
  String archiveName() {
    if (Platform.isMacOS) return 'evaporate-9.9.9-macos.zip';
    if (Platform.isWindows) return 'evaporate-9.9.9-windows.zip';
    return 'evaporate-9.9.9-linux.tar.gz';
  }

  group('подготовка обновления', () {
    test('архив скачивается, проверяется и распаковывается', () async {
      // tar.gz на Linux собирать сложнее, а проверяем мы не упаковщик.
      final name = Platform.isLinux
          ? 'evaporate-9.9.9-linux.tar.gz'
          : archiveName();
      final bytes = Platform.isLinux
          ? GZipEncoder().encodeBytes(
              TarEncoder().encodeBytes(
                Archive()
                  ..add(ArchiveFile.string('bundle/evaporate', 'бинарь')),
              ),
            )
          : zipOf({'Evaporate.app/Contents/MacOS/evaporate': 'бинарь'});

      final phases = <UpdatePhase>[];
      final root = await downloadOf(name: name, bytes: bytes).prepare(
        releaseWith(name: name, bytes: bytes),
        onProgress: (p) => phases.add(p.phase),
      );

      expect(Directory(root).existsSync(), isTrue);
      expect(phases, contains(UpdatePhase.downloading));
      expect(phases, contains(UpdatePhase.verifying));
      expect(phases, contains(UpdatePhase.unpacking));
      expect(phases.last, UpdatePhase.ready);
    });

    // Оборванная загрузка выглядит как целый файл: без проверки она уехала
    // бы поверх установки.
    test('не сошедшаяся сумма отменяет обновление', () async {
      final name = archiveName();
      final bytes = zipOf({'a': 'б'});

      await expectLater(
        downloadOf(
          name: name,
          bytes: bytes,
          sums:
              '0000000000000000000000000000000000000000000000000000000000000000  $name\n',
        ).prepare(releaseWith(name: name, bytes: bytes)),
        throwsA(isA<UpdateException>()),
      );
    });

    test('недобранный размер отменяет обновление', () async {
      final name = archiveName();
      final bytes = zipOf({'a': 'б'});
      final release = Release(
        version: '9.9.9',
        url: 'https://example.invalid/release',
        assets: [
          ReleaseAsset(
            name: name,
            url: 'https://example.invalid/$name',
            // Обещали больше, чем пришло.
            sizeBytes: bytes.length + 100,
          ),
        ],
      );

      await expectLater(
        downloadOf(name: name, bytes: bytes).prepare(release),
        throwsA(isA<UpdateException>()),
      );
    });

    // Настоящий архив сборки полон записей о папках, и косая черта на
    // конце — это не выход наружу, а обычная папка. Приняв её за выход,
    // обновление спотыкалось о первую же: `data/flutter_assets/assets/`.
    test('записи о папках не считаются выходом наружу', () async {
      final name = archiveName();
      final bytes = zipOf(
        {'Evaporate.app/Contents/MacOS/evaporate': 'бинарь'},
        dirs: [
          'Evaporate.app/',
          'Evaporate.app/Contents/',
          'data/flutter_assets/assets/',
        ],
      );

      final root = await downloadOf(
        name: name,
        bytes: bytes,
      ).prepare(releaseWith(name: name, bytes: bytes));

      expect(Directory(root).existsSync(), isTrue);
      expect(
        File(p.join(root, 'Contents', 'MacOS', 'evaporate')).existsSync(),
        isTrue,
      );
    }, skip: Platform.isLinux ? 'проверяется на zip' : null);

    // Ведущая косая черта делает путь абсолютным, и записать по нему
    // означало бы писать в корень диска. Такую запись не отклоняем, а
    // раскладываем внутрь — так же поступает всякий распаковщик.
    test('путь от корня раскладывается внутри папки', () async {
      final name = archiveName();
      // Второй файл рядом — чтобы папкой обновления считалась распакованная
      // целиком, а не единственная папка внутри неё.
      final bytes = zipOf({'/etc/подделка': 'нельзя', 'evaporate': 'бинарь'});

      final root = await downloadOf(
        name: name,
        bytes: bytes,
      ).prepare(releaseWith(name: name, bytes: bytes));

      expect(File(p.join(root, 'etc', 'подделка')).existsSync(), isTrue);
      expect(File('/etc/подделка').existsSync(), isFalse);
    }, skip: Platform.isLinux ? 'проверяется на zip' : null);

    // Та же мерка, что и у пакетов сохранений: архив приехал из сети.
    test('архив с выходом за пределы папки отклоняется', () async {
      final name = archiveName();
      final bytes = zipOf({'../снаружи': 'нельзя'});

      await expectLater(
        downloadOf(
          name: name,
          bytes: bytes,
        ).prepare(releaseWith(name: name, bytes: bytes)),
        throwsA(isA<UpdateException>()),
      );
    }, skip: Platform.isLinux ? 'проверяется на zip' : null);

    test('релиз без файла для этой системы обновиться не предлагает', () async {
      const release = Release(
        version: '9.9.9',
        url: 'https://example.invalid/release',
        assets: [
          ReleaseAsset(
            name: 'evaporate-9.9.9-plan9.zip',
            url: 'https://example.invalid/x',
            sizeBytes: 1,
          ),
        ],
      );

      await expectLater(
        UpdateDownload(workDir: tmp.path).prepare(release),
        throwsA(isA<UpdateException>()),
      );
    });

    // У старых релизов файла сумм нет вовсе, и это не повод отказываться:
    // размер уже проверен.
    test('недоступные суммы не отменяют обновление', () async {
      final name = archiveName();
      final bytes = zipOf({'Evaporate.app/Contents/MacOS/evaporate': 'б'});

      final root = await downloadOf(
        name: name,
        bytes: bytes,
        sumsFail: true,
      ).prepare(releaseWith(name: name, bytes: bytes));

      expect(Directory(root).existsSync(), isTrue);
    }, skip: Platform.isLinux ? 'проверяется на zip' : null);
  });

  group('куда ставить', () {
    // На macOS заменять надо бандл целиком, а не файл внутри него.
    test('на macOS папкой приложения считается бандл', () {
      final layout = InstallLayout.current(
        executablePath: '/Applications/Evaporate.app/Contents/MacOS/evaporate',
        platform: 'macos',
      );

      expect(layout!.root, '/Applications/Evaporate.app');
      expect(layout.executable, endsWith('MacOS/evaporate'));
    });

    test('на остальных системах — папка с исполняемым файлом', () {
      final layout = InstallLayout.current(
        executablePath: r'C:\Program Files\Evaporate\evaporate.exe',
        platform: 'windows',
      );

      expect(layout!.root, r'C:\Program Files\Evaporate');
    });

    test('исполняемый файл вне бандла на macOS обновить нечем', () {
      expect(
        InstallLayout.current(
          executablePath: '/usr/local/bin/evaporate',
          platform: 'macos',
        ),
        isNull,
      );
    });

    // На Linux приложение нередко лежит там, куда его положил пакетный
    // менеджер: писать туда нельзя, да и обновлять должен он же.
    test('недоступная на запись папка это видно заранее', () async {
      final layout = InstallLayout(
        root: p.join(tmp.path, 'нет-такой-папки'),
        executable: p.join(tmp.path, 'нет-такой-папки', 'evaporate'),
      );

      expect(await layout.isWritable, isFalse);
    });

    test('своя папка на запись доступна', () async {
      final layout = InstallLayout(
        root: tmp.path,
        executable: p.join(tmp.path, 'evaporate'),
      );

      expect(await layout.isWritable, isTrue);
      // Проба за собой убирает: файл в папке приложения никому не нужен.
      expect(
        Directory(tmp.path).listSync().where((e) => e.path.contains('probe')),
        isEmpty,
      );
    });
  });

  group('скрипт замены', () {
    const layout = InstallLayout(
      root: '/Applications/Evaporate.app',
      executable: '/Applications/Evaporate.app/Contents/MacOS/evaporate',
    );

    String windowsScript() => UpdateScript.build(
      layout: const InstallLayout(
        root: r'C:\Program Files\Evaporate',
        executable: r'C:\Program Files\Evaporate\evaporate.exe',
      ),
      stagedRoot: r'C:\Temp\staged',
      pid: 777,
      logPath: '/tmp/evaporate-update.log',
      platform: 'windows',
    );

    String posixScript() => UpdateScript.build(
      layout: layout,
      stagedRoot: '/tmp/staged/Evaporate.app',
      pid: 4242,
      logPath: '/tmp/evaporate-update.log',
      platform: 'macos',
    );

    // Порядок шагов и есть возможность откатиться: прежняя папка
    // отодвигается, а не удаляется, и убирается только после запуска новой.
    test('на posix прежняя папка отодвигается, а не удаляется', () {
      final script = posixScript();

      expect(script, contains('kill -0 4242'));
      expect(script, contains(r'swap "$root" "$backup"'));
      expect(
        script.indexOf(r'swap "$staged" "$root"'),
        greaterThan(script.indexOf(r'swap "$root" "$backup"')),
      );
      // Откат при сорвавшейся замене.
      expect(script, contains(r'swap "$backup" "$root"'));
      // Уборка прежней — после запуска новой, а не до.
      expect(
        script.lastIndexOf(r'rm -rf "$backup"'),
        greaterThan(script.indexOf(r'"$launch"')),
      );
    });

    test('на windows ждут исчезновения процесса по номеру', () {
      final script = windowsScript();

      expect(script, contains('Get-Process -Id 777'));
      expect(script, contains(r'Swap $root $backup'));
      expect(script, contains(r'Swap $backup $root'));
      expect(script, contains(r'Start-Process -FilePath $launch'));
    });

    // То, из-за чего обновление кончалось закрытым приложением: помощник
    // выходил на любом отказе, так и не запустив ничего. Остаться на прежней
    // версии терпимо, остаться вовсе без приложения — нет.
    test('приложение запускается при любом исходе', () {
      // Запуск стоит до проверки успеха — значит он безусловен. Внутри
      // ветки «получилось» он и был, когда обновление оставляло человека с
      // закрытым приложением.
      for (final (script, launch, verdict) in [
        (posixScript(), r'"$launch" >/dev/null', r'if [ "$replaced" -eq 1 ]'),
        (
          windowsScript(),
          r'Start-Process -FilePath $launch',
          r'if ($replaced)',
        ),
      ]) {
        expect(script, contains(launch));
        expect(script, contains(verdict));
        expect(
          script.indexOf(launch),
          lessThan(script.indexOf(verdict)),
          reason: 'запуск попал внутрь удачной ветки — после отката его нет',
        );
      }
    });

    // Помощник работает, когда приложения уже нет: рассказать о случившемся
    // ему больше нечем, а «закрылось и не открылось» без единого следа —
    // худшее, что может случиться с обновлением.
    test('помощник пишет о каждом шаге', () {
      for (final script in [posixScript(), windowsScript()]) {
        expect(script, contains('/tmp/evaporate-update.log'));
        expect(script, contains('не установлено, версия прежняя'));
        expect(script, contains('приложение не закрылось'));
      }
    });

    test('на windows помощник не зовёт внешних команд', () {
      final script = windowsScript();

      for (final external in ['tasklist', 'find ', 'ping ', 'timeout ']) {
        expect(
          script,
          isNot(contains(external)),
          reason: '«$external» откроет своё окно: консоли у помощника нет',
        );
      }
    });

    test('чем запускать и как называется — по системе', () {
      expect(UpdateScript.fileName(platform: 'windows'), endsWith('.ps1'));
      expect(UpdateScript.fileName(platform: 'linux'), endsWith('.sh'));

      final windows = UpdateScript.command('x.ps1', platform: 'windows');
      expect(windows.first, 'powershell');
      expect(windows, containsAllInOrder(['-WindowStyle', 'Hidden']));
      // Скрипт свой и только что записанный, но политика запуска по
      // умолчанию не даст выполнить и такой.
      expect(windows, containsAllInOrder(['-ExecutionPolicy', 'Bypass']));
      expect(windows.last, 'x.ps1');

      expect(UpdateScript.command('x.sh', platform: 'linux'), ['sh', 'x.sh']);
    });

    // Проверка на настоящем разборщике: скрипт пишется строкой, и опечатка
    // в нём выяснилась бы только на чужой машине, посреди обновления.
    // Идёт на сборке Windows — там PowerShell есть.
    test('скрипт разбирается самим PowerShell', () async {
      final file = File(p.join(tmp.path, 'probe.ps1'));
      await file.writeAsString(windowsScript());

      final read = "(Get-Content -Raw -LiteralPath '${file.path}')";
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "[void][ScriptBlock]::Create($read)",
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
    }, skip: Platform.isWindows ? null : 'PowerShell есть на Windows');

    // Путь может прийти с апострофом в имени пользователя, а строки в
    // PowerShell им же и закрываются.
    test('апостроф в пути не рвёт скрипт', () {
      final script = UpdateScript.build(
        layout: const InstallLayout(
          root: r"C:\Users\D'Artagnan\Evaporate",
          executable: r"C:\Users\D'Artagnan\Evaporate\evaporate.exe",
        ),
        stagedRoot: r'C:\Temp\staged',
        pid: 1,
        logPath: '/tmp/evaporate-update.log',
        platform: 'windows',
      );

      expect(script, contains(r"'C:\Users\D''Artagnan\Evaporate'"));
    });
  });

  group('записи помощника', () {
    // Помощник работает, когда приложения уже нет, и в общий журнал писать
    // ему нечем. Не забери приложение его файл при следующем запуске —
    // человек так и остался бы с «закрылось и не открылось» без объяснений.
    test('переезжают в журнал приложения и файл убирается', () async {
      final log = File(UpdateInstaller.logPath(tmp.path));
      await log.writeAsString(
        'обновление: начинаю\nобновление: не установлено, версия прежняя\n',
      );
      final appLog = AppLog(
        path: p.join(tmp.path, 'app.log'),
        previousPath: p.join(tmp.path, 'app.log.1'),
      );
      AppLog.instance = appLog;

      await UpdateInstaller.collectLog(tmp.path);
      await appLog.flush();

      expect(await log.exists(), isFalse);
      expect(await appLog.tail(), anyElement(contains('версия прежняя')));
    });

    test('отсутствие файла запуск не тревожит', () async {
      await UpdateInstaller.collectLog(tmp.path);
    });
  });

  group('запуск замены', () {
    test('скрипт пишется и запускается отдельным процессом', () async {
      final started = <List<String>>[];
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: tmp.path,
          executable: p.join(tmp.path, 'evaporate'),
        ),
        processId: 4242,
        start: (executable, arguments) async {
          started.add([executable, ...arguments]);
          // Настоящий процесс здесь ни к чему: проверяем, что запускаем.
          return Process.start('true', const []);
        },
      );

      await installer.apply(p.join(tmp.path, 'staged'));

      expect(started, hasLength(1));
      final script = File(p.join(tmp.path, UpdateScript.fileName()));
      expect(script.existsSync(), isTrue);
      expect(script.readAsStringSync(), contains('4242'));
      expect(started.single.last, script.path);
    }, skip: Platform.isWindows ? 'команда true есть не на Windows' : null);

    // На Linux приложение нередко лежит там, куда его положил пакетный
    // менеджер: молча не сработать хуже, чем честно отказаться.
    test('в папку без доступа на запись не ставим', () async {
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: p.join(tmp.path, 'нет-такой'),
          executable: p.join(tmp.path, 'нет-такой', 'evaporate'),
        ),
        processId: 1,
        start: (executable, arguments) async =>
            throw StateError('запускать не должны'),
      );

      expect(await installer.canInstall, isFalse);
      await expectLater(
        installer.apply(p.join(tmp.path, 'staged')),
        throwsA(isA<UpdateException>()),
      );
    });
  });
}
