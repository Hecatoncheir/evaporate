import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
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
  List<int> zipOf(Map<String, String> files) {
    final archive = Archive();
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

    // Порядок шагов и есть возможность откатиться: прежняя папка
    // отодвигается, а не удаляется, и убирается только после запуска новой.
    test('на posix прежняя папка отодвигается, а не удаляется', () {
      final script = UpdateScript.build(
        layout: layout,
        stagedRoot: '/tmp/staged/Evaporate.app',
        pid: 4242,
        platform: 'macos',
      );

      expect(script, contains('kill -0 4242'));
      expect(script, contains(r'mv "$root" "$backup"'));
      expect(
        script.indexOf(r'mv "$staged" "$root"'),
        greaterThan(script.indexOf(r'mv "$root" "$backup"')),
      );
      // Откат при сорвавшейся замене.
      expect(script, contains(r'mv "$backup" "$root"'));
      // Уборка прежней — после запуска новой, а не до.
      expect(
        script.lastIndexOf(r'rm -rf "$backup"'),
        greaterThan(script.indexOf(r'"$launch"')),
      );
    });

    test('на windows ждут исчезновения процесса по номеру', () {
      final script = UpdateScript.build(
        layout: const InstallLayout(
          root: r'C:\Program Files\Evaporate',
          executable: r'C:\Program Files\Evaporate\evaporate.exe',
        ),
        stagedRoot: r'C:\Temp\staged',
        pid: 777,
        platform: 'windows',
      );

      expect(script, contains('PID eq 777'));
      expect(script, contains(r'move "%root%" "%backup%"'));
      expect(script, contains(r'move "%backup%" "%root%"'));
      expect(script, contains(r'start "" "%launch%"'));
    });

    test('чем запускать и как называется — по системе', () {
      expect(UpdateScript.fileName(platform: 'windows'), endsWith('.cmd'));
      expect(UpdateScript.fileName(platform: 'linux'), endsWith('.sh'));
      expect(UpdateScript.command('x.cmd', platform: 'windows'), [
        'cmd',
        '/c',
        'x.cmd',
      ]);
      expect(UpdateScript.command('x.sh', platform: 'linux'), ['sh', 'x.sh']);
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
