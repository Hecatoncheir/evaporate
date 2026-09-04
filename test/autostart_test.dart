import 'dart:io';

import 'package:evaporate/services/system/autostart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('evaporate_autostart_');
  });

  tearDown(() async {
    try {
      if (await home.exists()) await home.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Autostart make({
    String executable = '/Приложения/Evaporate.app/Contents/MacOS/Evaporate',
    List<List<String>>? calls,
  }) {
    // Подделка ведёт себя как реестр: пока записи нет, query отвечает
    // ненулевым кодом. Прежняя отвечала успехом на всё подряд, и на Windows
    // «выключено» читалось как «включено» — тест проходил там, где не должен.
    var present = false;
    return Autostart(
      executablePath: executable,
      homeDir: home.path,
      environment: {'HOME': home.path},
      run: (exe, args) async {
        calls?.add([exe, ...args]);
        if (args.contains('add')) present = true;
        if (args.contains('delete')) present = false;
        if (args.contains('query')) {
          return ProcessResult(0, present ? 0 : 1, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );
  }

  group('содержимое записей', () {
    // launchd запускает бандл, а не файл внутри него: иначе приложение
    // стартует без значка в доке и без выданных бандлу прав.
    test('plist запускает бандл целиком', () {
      final plist = Autostart.macPlist('/Приложения/Evaporate.app');

      expect(plist, contains('<key>RunAtLoad</key>'));
      expect(plist, contains('/usr/bin/open'));
      expect(plist, contains('/Приложения/Evaporate.app'));
      expect(plist, startsWith('<?xml'));
    });

    test('desktop-запись помечена как приложение', () {
      final entry = Autostart.desktopEntry('/opt/evaporate/evaporate');

      expect(entry, startsWith('[Desktop Entry]'));
      expect(entry, contains('Type=Application'));
      expect(entry, contains('X-GNOME-Autostart-enabled=true'));
      // Кавычки: путь может содержать пробел.
      expect(entry, contains('Exec="/opt/evaporate/evaporate"'));
    });
  });

  group('путь запуска', () {
    test('на macOS берётся бандл, а не файл внутри него', () {
      final auto = make();

      expect(
        auto.target,
        Platform.isMacOS
            ? '/Приложения/Evaporate.app'
            : '/Приложения/Evaporate.app/Contents/MacOS/Evaporate',
      );
    });

    test('путь без бандла остаётся как есть', () {
      final auto = make(executable: '/usr/local/bin/evaporate');

      expect(auto.target, '/usr/local/bin/evaporate');
    });
  });

  group('включение и выключение', () {
    test('включение создаёт запись, выключение убирает', () async {
      final auto = make();
      final file = auto.entryFile;
      if (file == null) return; // Windows: записи в файле нет.

      expect(await auto.isEnabled(), isFalse);

      await auto.setEnabled(true);
      expect(await auto.isEnabled(), isTrue);
      expect(await File(file).readAsString(), isNotEmpty);

      await auto.setEnabled(false);
      expect(await auto.isEnabled(), isFalse);
      expect(await File(file).exists(), isFalse);
    });

    test('повторное выключение не считается ошибкой', () async {
      final auto = make();

      await auto.setEnabled(false);
      await auto.setEnabled(false);

      expect(await auto.isEnabled(), isFalse);
    });

    test('повторное включение перезаписывает, а не двоит', () async {
      final auto = make();
      final file = auto.entryFile;
      if (file == null) return;

      await auto.setEnabled(true);
      await auto.setEnabled(true);

      final dir = Directory(p.dirname(file));
      expect(dir.listSync().whereType<File>(), hasLength(1));
    });

    test('нужные папки создаются сами', () async {
      final auto = make();
      final file = auto.entryFile;
      if (file == null) return;

      expect(Directory(p.dirname(file)).existsSync(), isFalse);
      await auto.setEnabled(true);

      expect(await File(file).exists(), isTrue);
    });
  });

  group('команды реестра', () {
    test('ненулевой exitCode reg add не считается успехом', () async {
      final auto = Autostart(
        operatingSystem: 'windows',
        executablePath: r'C:\Evaporate.exe',
        run: (exe, args) async => ProcessResult(0, 1, '', 'Access denied'),
      );
      await expectLater(
        auto.setEnabled(true),
        throwsA(isA<ProcessException>()),
      );
    });

    test('ненулевой exitCode reg delete не считается успехом', () async {
      final auto = Autostart(
        operatingSystem: 'windows',
        executablePath: r'C:\Evaporate.exe',
        run: (exe, args) async => ProcessResult(
          0,
          args.first == 'query' ? 0 : 1,
          '',
          'Access denied',
        ),
      );
      await expectLater(
        auto.setEnabled(false),
        throwsA(isA<ProcessException>()),
      );
    });
    // Сами команды собираются одинаково на любой системе, поэтому
    // проверить их можно и не на Windows.
    test('запись идёт в ветку текущего пользователя', () {
      final args = Autostart.addArgs(r'C:\Program Files\Evaporate.exe');

      expect(args.first, 'add');
      expect(args[1], startsWith(r'HKCU\'));
      expect(
        args,
        contains('/f'),
        reason: 'без него reg спросит подтверждение и повиснет',
      );
    });

    // Иначе система прочитает путь до первого пробела.
    test('путь с пробелом берётся в кавычки', () {
      final args = Autostart.addArgs(r'C:\Program Files\Evaporate.exe');

      final value = args[args.indexOf('/d') + 1];
      expect(value, r'"C:\Program Files\Evaporate.exe"');
    });

    test('удаление не спрашивает подтверждения', () {
      expect(Autostart.removeArgs(), containsAllInOrder(['delete']));
      expect(Autostart.removeArgs(), contains('/f'));
    });

    // Единственная настоящая проверка реестра: на других системах её
    // выполнить нечем, поэтому в CI её гоняет сборка под Windows.
    test('включение и выключение доходят до реестра', () async {
      final auto = Autostart(
        executablePath: r'C:\Program Files\Evaporate\Evaporate.exe',
      );
      addTearDown(() => auto.setEnabled(false));

      await auto.setEnabled(true);
      expect(await auto.isEnabled(), isTrue);

      await auto.setEnabled(false);
      expect(await auto.isEnabled(), isFalse);
    }, skip: Platform.isWindows ? false : 'реестр есть только на Windows');
  });

  group('домашняя папка неизвестна', () {
    test('без HOME включение не падает', () async {
      final auto = Autostart(
        executablePath: '/opt/evaporate/evaporate',
        homeDir: null,
        environment: const {},
        run: (exe, args) async => ProcessResult(0, 1, '', ''),
      );

      // Ничего не сделаем, но и не уроним приложение.
      await auto.setEnabled(true);
      expect(await auto.isEnabled(), isFalse);
    });
  });
}
