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

import '../../support/temp_dir.dart';

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
    await deleteTempDir(tmp);
  });

  Future<Process> dummyProcess() => Platform.isWindows
      ? Process.start('cmd', const ['/c', 'exit', '0'])
      : Process.start('true', const []);

  /// Папка Linux в том виде, в каком её кладёт сборка: исполняемый файл,
  /// библиотеки, данные и маркер — ничего больше.
  Future<InstallLayout> ownInstall(String name) async {
    final root = p.join(tmp.path, name);
    await Directory(p.join(root, 'lib')).create(recursive: true);
    await Directory(p.join(root, 'data')).create(recursive: true);
    await File(p.join(root, 'evaporate')).writeAsString('#!/bin/sh\n');
    await File(p.join(root, InstallLayout.marker)).writeAsString('');
    return InstallLayout(root: root, executable: p.join(root, 'evaporate'));
  }

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

  /// Архив с символическими ссылками — как его пишет `ditto`.
  ///
  /// Ссылка в zip — запись с типом `0120000` в старших битах атрибутов и
  /// путём вместо содержимого, а признают её, только если архив сделан на
  /// Unix. `ZipEncoder` честно пишет «MS-DOS», поэтому систему в
  /// центральном каталоге переставляем сами.
  List<int> zipWithLinks(Map<String, String> files, Map<String, String> links) {
    final archive = Archive();
    files.forEach((name, content) {
      archive.add(ArchiveFile.string(name, content)..mode = 0x81ED);
    });
    links.forEach((name, target) {
      archive.add(ArchiveFile.string(name, target)..mode = 0xA1ED);
    });
    final bytes = ZipEncoder().encode(archive);
    for (var i = 0; i + 5 < bytes.length; i++) {
      final central =
          bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4b &&
          bytes[i + 2] == 0x01 &&
          bytes[i + 3] == 0x02;
      if (central) bytes[i + 5] = 3;
    }
    return bytes;
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
    List<int>? askedFrom,
    bool ignoresRange = false,
  }) => UpdateDownload(
    workDir: tmp.path,
    platform: platform ?? archivePlatform(),
    fetch: (uri, onProgress) async {
      // Целиком читаются только суммы: сборка идёт мимо памяти, на диск.
      if (!uri.path.endsWith('SHA256SUMS')) {
        throw StateError('в память запрошено лишнее: $uri');
      }
      if (sumsFail) throw const SocketException('нет связи');
      return utf8.encode(sums ?? '${sha256.convert(bytes)}  $name\n');
    },
    download: (uri, target, from, onProgress) async {
      askedFrom?.add(from);
      // Сервер, умеющий докачку, дошлёт хвост; не умеющий ответит целым
      // файлом, и прежний кусок надо выбросить, а не дополнить им.
      final resumes = from > 0 && !ignoresRange;
      await target.writeAsBytes(
        resumes ? bytes.sublist(from) : bytes,
        mode: resumes ? FileMode.append : FileMode.writeOnly,
        flush: true,
      );
      onProgress(bytes.length, bytes.length);
    },
  );

  /// Недокачанный кусок в том виде, в каком его оставляет обрыв связи.
  Future<File> halfDownloaded(String name, List<int> bytes, int have) async {
    final dir = Directory(p.join(tmp.path, 'updates', '9.9.9'));
    await dir.create(recursive: true);
    final part = File(p.join(dir.path, '$name.part'));
    await part.writeAsBytes(bytes.sublist(0, have), flush: true);
    return part;
  }

  // Имя архива для своей системы приходит из релиза, а какое оно — знает
  // сборка. Тест берёт то же, что и приложение.
  String archiveName() => archivePlatform() == 'linux'
      ? 'evaporate-9.9.9${Release.updateSuffix('linux')}'
      : 'evaporate-9.9.9-macos.zip';

  group('подготовка обновления', () {
    // Полсотни мегабайт по плохому каналу обрываются регулярно. Без
    // продолжения каждая попытка начиналась бы с нуля — то есть на таком
    // канале не заканчивалась бы никогда.
    test('оборванная загрузка продолжается с места обрыва', () async {
      const name = 'evaporate-9.9.9-windows-setup.exe';
      final bytes = utf8.encode('установщик целиком, все его байты');
      await halfDownloaded(name, bytes, 10);
      final askedFrom = <int>[];

      final setup = await downloadOf(
        name: name,
        bytes: bytes,
        platform: 'windows',
        askedFrom: askedFrom,
      ).prepare(releaseWith(name: name, bytes: bytes));

      expect(askedFrom, [10]);
      expect(File(setup).readAsBytesSync(), bytes);
    });

    // Докачку сервер поддерживать не обязан: не умеет — отвечает целым
    // файлом, и склеить его с прежним куском значило бы получить мусор
    // полуторной длины.
    test(
      'сервер без докачки отдаёт файл целиком, и кусок не склеивается',
      () async {
        const name = 'evaporate-9.9.9-windows-setup.exe';
        final bytes = utf8.encode('установщик целиком, все его байты');
        await halfDownloaded(name, bytes, 10);

        final setup = await downloadOf(
          name: name,
          bytes: bytes,
          platform: 'windows',
          ignoresRange: true,
        ).prepare(releaseWith(name: name, bytes: bytes));

        expect(File(setup).readAsBytesSync(), bytes);
      },
    );

    // Докачка чинит обрыв связи, а не подмену байтов: продолжив испорченный
    // кусок, сумма не сойдётся уже никогда, и обновление встало бы намертво.
    test('не сошедшийся кусок не остаётся лежать', () async {
      const name = 'evaporate-9.9.9-windows-setup.exe';
      final bytes = utf8.encode('установщик');
      final part = await halfDownloaded(name, bytes, 4);

      await expectLater(
        downloadOf(
          name: name,
          bytes: bytes,
          platform: 'windows',
          sums: '${'0' * 64}  $name',
        ).prepare(releaseWith(name: name, bytes: bytes)),
        throwsA(isA<UpdateException>()),
      );

      expect(part.existsSync(), isFalse);
    });

    test('архив скачивается, проверяется и распаковывается', () async {
      // tar.gz на Linux собирать сложнее, а проверяем мы не упаковщик.
      final name = archiveName();
      final bytes = Platform.isLinux
          ? const GZipEncoder().encodeBytes(
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

    // Бандл macOS держится на ссылках: `Versions/Current` и бинарник
    // фреймворка. Распаковщик их не знал и клал файлами с путём внутри —
    // обновлённое приложение не запускалось, а прежнее уже было убрано.
    test('ссылки бандла переживают распаковку ссылками', () async {
      const name = 'evaporate-9.9.9-macos.zip';
      const framework = 'Evaporate.app/Contents/Frameworks/App.framework';
      final bytes = zipWithLinks(
        {
          'Evaporate.app/Contents/MacOS/evaporate': 'бинарь',
          '$framework/Versions/A/App': 'код',
        },
        {
          '$framework/Versions/Current': 'A',
          '$framework/App': 'Versions/Current/App',
        },
      );

      final root = await downloadOf(
        name: name,
        bytes: bytes,
        platform: 'macos',
      ).prepare(releaseWith(name: name, bytes: bytes));

      final frameworkDir = p.join(
        root,
        'Contents',
        'Frameworks',
        'App.framework',
      );
      final current = p.join(frameworkDir, 'Versions', 'Current');
      expect(FileSystemEntity.isLinkSync(current), isTrue);
      expect(Link(current).targetSync(), 'A');
      final binary = p.join(frameworkDir, 'App');
      expect(FileSystemEntity.isLinkSync(binary), isTrue);
      expect(File(binary).readAsStringSync(), 'код');
    }, skip: Platform.isWindows ? 'бандлы macOS разворачивают не здесь' : null);

    // Ссылка — такой же выход наружу, как `..` в имени: всё, что ляжет
    // «внутрь» неё, ляжет туда, куда она указывает.
    for (final target in ['../../../outside', '/etc', 'Versions/../../..']) {
      test('ссылка наружу ($target) отменяет обновление', () async {
        const name = 'evaporate-9.9.9-macos.zip';
        final bytes = zipWithLinks(
          {'Evaporate.app/Contents/MacOS/evaporate': 'бинарь'},
          {'Evaporate.app/Contents/escape': target},
        );

        await expectLater(
          downloadOf(
            name: name,
            bytes: bytes,
            platform: 'macos',
          ).prepare(releaseWith(name: name, bytes: bytes)),
          throwsA(isA<UpdateException>()),
        );
      });
    }

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
        layout: await ownInstall('app'),
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

      // Журнал передаётся, а не ставится глобалом: поставленный и не
      // возвращённый обратно, он утащил бы к себе записи следующих тестов.
      await UpdateInstaller.collectLog(tmp.path, log: appLog);
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
          layout: await ownInstall('app'),
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

    // Замена идёт последним, что делает приложение перед закрытием, и
    // единственный след её начала — эта строка: не запишись она в тот же
    // журнал, что читает человек, «окно закрылось и не открылось»
    // осталось бы без объяснений.
    test('о начале замены пишут в переданный журнал', () async {
      final journal = AppLog(
        path: p.join(tmp.path, 'app.log'),
        previousPath: p.join(tmp.path, 'app.log.1'),
      );
      final setup = File(p.join(tmp.path, 'evaporate-9.9.9-windows-setup.exe'));
      await setup.writeAsBytes(const [1]);
      await File(p.join(tmp.path, 'unins000.exe')).writeAsBytes(const [1]);
      final installer = UpdateInstaller(
        workDir: tmp.path,
        layout: InstallLayout(
          root: tmp.path,
          executable: p.join(tmp.path, 'evaporate.exe'),
        ),
        platform: 'windows',
        start: (executable, arguments) async => dummyProcess(),
        log: () => journal,
      );

      await installer.apply(setup.path);
      await journal.flush();

      expect(await journal.tail(), anyElement(contains('запускаю setup')));
    });

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

    // Приложение живо в тот миг, когда запускает установщик: закрыться
    // раньше значило бы, что запускать его уже некому. Файлы работающего
    // приложения Windows заменить не даёт, поэтому установщику передают
    // номер процесса — дождаться выхода.
    test('setup получает номер процесса, чтобы дождаться выхода', () async {
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
        processId: 4242,
        platform: 'windows',
        start: (executable, arguments) async {
          started.add([executable, ...arguments]);
          return dummyProcess();
        },
      );

      await installer.apply(setup.path);

      expect(started.single, contains('/WAITPID=4242'));
      expect(
        started.single,
        contains('/LOG=${UpdateInstaller.setupLogPath(tmp.path)}'),
      );
    });

    // Ждать установщик умеет не сам по себе: это дописано в installer.iss,
    // и потерять одну из половин ничего не стоит — приложение передаст
    // номер процесса, а установщик о нём не спросит.
    test('installer.iss умеет ждать переданный номер процесса', () {
      final iss = File('windows/installer.iss').readAsStringSync();

      expect(iss, contains('/WAITPID='));
      expect(iss, contains('WaitForSingleObject'));
      expect(iss, contains('function InitializeSetup'));
    });

    // Установка могла сорваться: файл занят, прав не хватило, диск полон.
    // Раньше об этом не оставалось ни следа — человек видел прежнюю версию
    // и гадал.
    test('отказ установщика попадает в журнал приложения', () async {
      await File(UpdateInstaller.setupLogPath(tmp.path)).writeAsString(
        [
          '2026-09-13 14:48:10.000   Starting the installation process.',
          '2026-09-13 14:48:11.000   Setup aborted: файл занят другим',
          '2026-09-13 14:48:11.000   Deinitializing setup.',
        ].join(Platform.lineTerminator),
      );
      final appLog = AppLog(
        path: p.join(tmp.path, 'app.log'),
        previousPath: p.join(tmp.path, 'app.log.1'),
      );

      await UpdateInstaller.collectLog(tmp.path, log: appLog);
      await appLog.flush();

      final written = (await appLog.tail()).join(Platform.lineTerminator);
      expect(written, contains('Setup aborted'));
      expect(written, isNot(contains('Starting the installation')));
      expect(
        File(UpdateInstaller.setupLogPath(tmp.path)).existsSync(),
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

  // Папкой приложения считается та, где лежит исполняемый файл, а замена
  // удаляет её целиком. Архив, распакованный прямо в «Загрузки», делал
  // папкой приложения сами «Загрузки» — и обновление уносило их со всем
  // содержимым.
  group('чужая папка', () {
    Future<UpdateInstaller> installerFor(InstallLayout layout) async =>
        UpdateInstaller(
          workDir: p.join(tmp.path, 'work'),
          layout: layout,
          processId: 1,
          platform: 'linux',
          start: (executable, arguments) async =>
              throw StateError('запускать не должны'),
        );

    test('сборка, распакованная в «Загрузки», себя не обновляет', () async {
      final layout = await ownInstall('Downloads');
      await File(p.join(layout.root, InstallLayout.marker)).delete();
      await File(p.join(layout.root, 'отпуск.jpg')).writeAsString('фото');
      final installer = await installerFor(layout);

      expect(await installer.canInstall, isFalse);
      await expectLater(
        installer.apply(p.join(tmp.path, 'staged')),
        throwsA(isA<UpdateException>()),
      );
      expect(File(p.join(layout.root, 'отпуск.jpg')).existsSync(), isTrue);
    });

    // `.run --extract` и распаковка руками поверх чужой папки приносят
    // маркер вместе со сборкой — а чужое остаётся лежать рядом.
    test('маркер рядом с чужим не делает папку своей', () async {
      final layout = await ownInstall('apps');
      await Directory(p.join(layout.root, 'другая-игра')).create();

      expect(await (await installerFor(layout)).canInstall, isFalse);
    });

    // Прежние сборки маркера не клали; обновлять их папку по нажатию нельзя
    // хотя бы потому, что помощник у них старый.
    test('папка без маркера своей не считается', () async {
      final layout = await ownInstall('old');
      await File(p.join(layout.root, InstallLayout.marker)).delete();

      expect(await (await installerFor(layout)).canInstall, isFalse);
    });

    test('папка сборки с маркером обновляется', () async {
      final layout = await ownInstall('app');

      expect(await (await installerFor(layout)).canInstall, isTrue);
    });
  });

  // Помощник — последний рубеж перед `rm -rf`, и проверять его стоит
  // настоящим `sh`, а не поиском строк в тексте скрипта.
  group(
    'помощник на деле',
    () {
      Future<String> runHelper(InstallLayout layout, String staged) async {
        final gone = await Process.start('true', const []);
        await gone.exitCode;
        final log = p.join(tmp.path, 'helper.log');
        final script = File(p.join(tmp.path, UpdateScript.fileName));
        await script.writeAsString(
          UpdateScript.build(
            layout: layout,
            stagedRoot: staged,
            pid: gone.pid,
            logPath: log,
          ),
        );
        final result = await Process.run('sh', [script.path]);
        expect(result.stderr, isEmpty);
        return File(log).readAsString();
      }

      Future<String> newBuild() async {
        final staged = await ownInstall(p.join('staged', 'evaporate'));
        await File(staged.executable).writeAsString('#!/bin/sh\n# новая\n');
        return staged.root;
      }

      test('сборка в своей папке заменяется, прежняя убирается', () async {
        final layout = await ownInstall('app');
        final staged = await newBuild();

        final log = await runHelper(layout, staged);

        expect(log, contains('установлено'));
        expect(File(layout.executable).readAsStringSync(), contains('новая'));
        expect(
          Directory('${layout.root}${UpdateScript.backupSuffix}').existsSync(),
          isFalse,
        );
      });

      test('чужой файл в папке приложения переживает обновление', () async {
        final layout = await ownInstall('Downloads');
        await File(p.join(layout.root, InstallLayout.marker)).delete();
        final photo = File(p.join(layout.root, 'отпуск.jpg'));
        await photo.writeAsString('фото');
        final staged = await newBuild();

        final log = await runHelper(layout, staged);

        expect(log, contains('не похожа на папку сборки'));
        expect(photo.readAsStringSync(), 'фото');
        expect(
          File(layout.executable).readAsStringSync(),
          isNot(contains('новая')),
        );
        expect(Directory(staged).existsSync(), isTrue);
      });

      // `mv` в существующую папку кладёт установку внутрь неё, а `rm -rf`
      // перед ним снёс бы то, что там лежит. Чужое на месте отодвинутого не
      // трогаем вовсе.
      test('чужое на месте отодвинутой копии не удаляется', () async {
        final layout = await ownInstall('app');
        final occupied = Directory(
          '${layout.root}${UpdateScript.backupSuffix}',
        );
        await occupied.create();
        final note = File(p.join(occupied.path, 'заметки.txt'));
        await note.writeAsString('моё');
        final staged = await newBuild();

        final log = await runHelper(layout, staged);

        expect(log, contains('лежит чужое'));
        expect(note.readAsStringSync(), 'моё');
        expect(
          File(layout.executable).readAsStringSync(),
          isNot(contains('новая')),
        );
      });
    },
    skip: Platform.isWindows
        ? 'POSIX-помощник не запускается на Windows'
        : null,
  );
}
