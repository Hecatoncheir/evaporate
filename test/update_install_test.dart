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

  Future<Process> dummyProcess() => Platform.isWindows
      ? Process.start('cmd', const ['/c', 'exit', '0'])
      : Process.start('true', const []);

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

  String archivePlatform() => Platform.isLinux ? 'linux' : 'macos';

  /// Подделка сети: отдаёт архив и суммы, ничего никуда не отправляя.
  UpdateDownload downloadOf({
    required String name,
    required List<int> bytes,
    String? sums,
    bool sumsFail = false,
    String? platform,
  }) => UpdateDownload(
    workDir: tmp.path,
    platform: platform ?? archivePlatform(),
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
  String archiveName() => archivePlatform() == 'linux'
      ? 'evaporate-9.9.9-linux.tar.gz'
      : 'evaporate-9.9.9-macos.zip';

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

    test('windows setup сохраняется без распаковки', () async {
      const name = 'evaporate-9.9.9-windows-setup.exe';
      final bytes = utf8.encode('setup');
      final phases = <UpdatePhase>[];

      final setup =
          await downloadOf(
            name: name,
            bytes: bytes,
            platform: 'windows',
          ).prepare(
            releaseWith(name: name, bytes: bytes),
            onProgress: (progress) => phases.add(progress.phase),
          );

      expect(setup, endsWith(name));
      expect(await File(setup).readAsBytes(), bytes);
      expect(phases, isNot(contains(UpdatePhase.unpacking)));
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

    String posixScript() => UpdateScript.build(
      layout: layout,
      stagedRoot: '/tmp/staged/Evaporate.app',
      pid: 4242,
      logPath: '/tmp/evaporate-update.log',
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

    // То, из-за чего обновление кончалось закрытым приложением: помощник
    // выходил на любом отказе, так и не запустив ничего. Остаться на прежней
    // версии терпимо, остаться вовсе без приложения — нет.
    test('приложение запускается при любом исходе', () {
      // Запуск стоит до проверки успеха — значит он безусловен. Внутри
      // ветки «получилось» он и был, когда обновление оставляло человека с
      // закрытым приложением.
      final script = posixScript();
      const launch = r'"$launch" >/dev/null';
      const verdict = r'if [ "$replaced" -eq 1 ]';
      expect(script, contains(launch));
      expect(script, contains(verdict));
      expect(
        script.indexOf(launch),
        lessThan(script.indexOf(verdict)),
        reason: 'запуск попал внутрь удачной ветки — после отката его нет',
      );
    });

    // Помощник работает, когда приложения уже нет: рассказать о случившемся
    // ему больше нечем, а «закрылось и не открылось» без единого следа —
    // худшее, что может случиться с обновлением.
    test('помощник пишет о каждом шаге', () {
      final script = posixScript();
      expect(script, contains('/tmp/evaporate-update.log'));
      expect(script, contains('не установлено, версия прежняя'));
      expect(script, contains('приложение не закрылось'));
    });

    test('помощник остался только для posix', () {
      expect(UpdateScript.fileName, endsWith('.sh'));

      final posix = UpdateScript.command('x.sh');
      expect(posix, ['sh', 'x.sh']);
    });

    // В sh апостроф закрывает одинарную строку.
    test('апостроф в пути не рвёт скрипт', () {
      final script = UpdateScript.build(
        layout: const InstallLayout(
          root: "/Users/D'Artagnan/Evaporate.app",
          executable:
              "/Users/D'Artagnan/Evaporate.app/Contents/MacOS/evaporate",
        ),
        stagedRoot: '/tmp/staged',
        pid: 1,
        logPath: '/tmp/evaporate-update.log',
      );

      expect(script, contains(r"'/Users/D'\''Artagnan/Evaporate.app'"));
    });
  });

  group('файл помощника', () {
    Future<File> written() async {
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: tmp.path,
          executable: p.join(tmp.path, 'evaporate'),
        ),
        processId: 1,
        platform: 'linux',
        start: (executable, arguments) async => dummyProcess(),
      );
      await installer.apply(p.join(tmp.path, 'staged'));
      return File(p.join(tmp.path, UpdateScript.fileName));
    }

    // У `sh` наоборот: метка перед `#!` сделала бы файл незапускаемым.
    test('скрипт для posix начинается с shebang', () async {
      final bytes = await (await written()).readAsBytes();

      expect(bytes.take(2), '#!'.codeUnits);
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
    test(
      'скрипт пишется и запускается отдельным процессом',
      () async {
        final started = <List<String>>[];
        final installer = UpdateInstaller(
          workDir: tmp.path,
          layout: InstallLayout(
            root: tmp.path,
            executable: p.join(tmp.path, 'evaporate'),
          ),
          processId: 4242,
          platform: 'linux',
          start: (executable, arguments) async {
            started.add([executable, ...arguments]);
            // Настоящий процесс здесь ни к чему: проверяем, что запускаем.
            return dummyProcess();
          },
        );

        await installer.apply(p.join(tmp.path, 'staged'));

        expect(started, hasLength(1));
        final script = File(p.join(tmp.path, UpdateScript.fileName));
        expect(script.existsSync(), isTrue);
        expect(script.readAsStringSync(), contains('4242'));
        expect(started.single.last, script.path);
      },
      skip: Platform.isWindows
          ? 'POSIX-помощник не запускается на Windows'
          : null,
    );

    test('windows запускает setup напрямую, без PowerShell', () async {
      final setup = File(p.join(tmp.path, 'evaporate-9.9.9-windows-setup.exe'));
      await setup.writeAsBytes(const [1]);
      await File(p.join(tmp.path, 'unins000.exe')).writeAsBytes(const [1]);
      final started = <List<String>>[];
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: tmp.path,
          executable: p.join(tmp.path, 'evaporate.exe'),
        ),
        platform: 'windows',
        start: (executable, arguments) async {
          started.add([executable, ...arguments]);
          return dummyProcess();
        },
      );

      expect(await installer.canInstall, isTrue);
      await installer.apply(setup.path);

      expect(started, hasLength(1));
      expect(started.single.first, setup.path);
      expect(
        started.single,
        containsAll(['/VERYSILENT', '/CLOSEAPPLICATIONS', '/RELAUNCH']),
      );
      expect(
        started.single.any(
          (argument) => argument.toLowerCase().contains('powershell'),
        ),
        isFalse,
      );
      expect(
        File(p.join(tmp.path, 'evaporate-update.ps1')).existsSync(),
        isFalse,
      );
    });

    test('portable windows-копию автоматически не обновляем', () async {
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: tmp.path,
          executable: p.join(tmp.path, 'evaporate.exe'),
        ),
        platform: 'windows',
      );

      expect(await installer.canInstall, isFalse);
    });

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
