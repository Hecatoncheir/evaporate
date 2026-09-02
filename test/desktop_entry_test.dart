import 'dart:io';

import 'package:evaporate/services/system/desktop_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('evaporate_desktop_');
  });

  tearDown(() async {
    try {
      if (await home.exists()) await home.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  DesktopEntry make({String executable = '/opt/Мои игры/evaporate'}) =>
      DesktopEntry(
        executablePath: executable,
        homeDir: home.path,
        environment: {'HOME': home.path},
      );

  group('содержимое записи', () {
    test('запись помечена приложением и игрой', () {
      final text = DesktopEntry.contents('/opt/evaporate', '/opt/icon.png');

      expect(text, startsWith('[Desktop Entry]'));
      expect(text, contains('Type=Application'));
      expect(text, contains('Categories=Game;'));
      expect(text, contains('Icon=/opt/icon.png'));
    });

    // Приложение может лежать в папке с пробелом, а Exec разбирается по
    // словам — без кавычек система запустила бы «/opt/Мои».
    test('путь с пробелом берётся в кавычки', () {
      final text = DesktopEntry.contents('/opt/Мои игры/evaporate', '/i.png');

      expect(text, contains('Exec="/opt/Мои игры/evaporate" %U'));
    });
  });

  group('установка', () {
    test('запись ложится в пользовательскую папку меню', () async {
      final entry = make();
      final file = entry.entryFile!;

      expect(file, contains(p.join('.local', 'share', 'applications')));
      expect(
        file,
        endsWith(DesktopEntry.fileName),
        reason: 'имя файла определяет, чем система его опознает',
      );
    });

    test('добавление и удаление работают', () async {
      final entry = make();

      expect(await entry.isInstalled(), isFalse);

      await entry.install();
      expect(await entry.isInstalled(), isTrue);
      expect(
        await File(entry.entryFile!).readAsString(),
        contains('Evaporate'),
      );

      await entry.remove();
      expect(await entry.isInstalled(), isFalse);
    });

    test('повторное удаление не считается ошибкой', () async {
      final entry = make();

      await entry.remove();
      await entry.remove();

      expect(await entry.isInstalled(), isFalse);
    });

    test('нужные папки создаются сами', () async {
      final entry = make();

      await entry.install();

      expect(await File(entry.entryFile!).exists(), isTrue);
    });

    test('XDG_DATA_HOME уважается', () {
      final custom = p.join(home.path, 'своё-место');
      final entry = DesktopEntry(
        executablePath: '/opt/evaporate',
        homeDir: home.path,
        environment: {'HOME': home.path, 'XDG_DATA_HOME': custom},
      );

      expect(entry.entryFile, startsWith(custom));
    });

    test('без HOME установка не падает', () async {
      final entry = DesktopEntry(
        executablePath: '/opt/evaporate',
        homeDir: null,
        environment: const {},
      );

      await entry.install();
      expect(await entry.isInstalled(), isFalse);
    });
  });

  group('область применения', () {
    // На macOS и Windows меню приложений устроено иначе, и предлагать это
    // действие там незачем.
    test('действие предлагается только на Linux', () {
      expect(make().isSupported, Platform.isLinux);
    });

    test('иконка ищется рядом с исполняемым файлом', () {
      final entry = make(executable: '/opt/evaporate/evaporate');

      expect(entry.iconPath, '/opt/evaporate/data/app_icon.png');
    });
  });
}
