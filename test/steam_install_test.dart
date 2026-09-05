import 'dart:io';

import 'package:evaporate/services/launch/game_roots.dart';
import 'package:evaporate/services/launch/steam_install.dart';
import 'package:evaporate/services/launch/vdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Steam держит на диске то, что приложение иначе угадывает: точный `appid`
/// и точное название. По идентификатору ищутся пути сохранений, и каталог
/// прямо оговаривает, что совпадение названия другой игры подставило бы
/// чужие сейвы, — пока идентификатор был догадкой, оговорка защищала лишь
/// наполовину.
void main() {
  group('разбор VDF', () {
    test('вложенные блоки и значения читаются', () {
      const source = '''
"AppState"
{
\t"appid"\t\t"478980"
\t"name"\t\t"Mansions of Madness"
\t"installdir"\t\t"Mansions of Madness"
\t"UserConfig"
\t{
\t\t"language"\t\t"russian"
\t}
}
''';

      final doc = Vdf.parse(source);

      expect(Vdf.string(doc, ['AppState', 'appid']), '478980');
      // Пробелы внутри значения — обычное дело, резать строку по ним нельзя.
      expect(Vdf.string(doc, ['AppState', 'name']), 'Mansions of Madness');
      expect(
        Vdf.string(doc, ['AppState', 'UserConfig', 'language']),
        'russian',
      );
    });

    // Пути Windows записаны с удвоенными слешами.
    test('экранированные слеши разворачиваются', () {
      final doc = Vdf.parse(
        '"libraryfolders"\n{\n"path" "D:\\\\SteamLibrary"\n}\n',
      );

      expect(Vdf.string(doc, ['libraryfolders', 'path']), r'D:\SteamLibrary');
    });

    // Файл принадлежит чужой программе: падать из-за его формата незачем.
    test('мусор не роняет разбор', () {
      expect(Vdf.parse('совсем не vdf'), isEmpty);
      expect(Vdf.parse('}\n}\n"a" "b"'), containsPair('a', 'b'));
    });

    test('вложенный ключ не путается с одноимённым верхним', () {
      const source = '''
"AppState"
{
\t"name"\t\t"Игра"
\t"UserConfig"
\t{
\t\t"name"\t\t"не то"
\t}
}
''';

      expect(Vdf.string(Vdf.parse(source), ['AppState', 'name']), 'Игра');
    });
  });

  group('установленное Steam', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_steam_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    /// Раскладка настоящей установки Steam в миниатюре.
    Future<String> makeSteam(
      String name, {
      List<({int id, String title, String folder})> apps = const [],
      List<String> extraLibraries = const [],
      bool createFolders = true,
    }) async {
      final root = Directory(p.join(tmp.path, name));
      final steamapps = Directory(p.join(root.path, 'steamapps'));
      await steamapps.create(recursive: true);

      final buffer = StringBuffer('"libraryfolders"\n{\n\t"0"\n\t{\n')
        ..write('\t\t"path"\t\t"${root.path}"\n\t}\n');
      var index = 1;
      for (final extra in extraLibraries) {
        buffer.write('\t"${index++}"\n\t{\n\t\t"path"\t\t"$extra"\n\t}\n');
      }
      buffer.write('}\n');
      await File(p.join(steamapps.path, 'libraryfolders.vdf'))
          .writeAsString(buffer.toString());

      for (final app in apps) {
        await File(p.join(steamapps.path, 'appmanifest_${app.id}.acf'))
            .writeAsString(
              '"AppState"\n{\n'
              '\t"appid"\t\t"${app.id}"\n'
              '\t"name"\t\t"${app.title}"\n'
              '\t"installdir"\t\t"${app.folder}"\n'
              '}\n',
            );
        if (createFolders) {
          await Directory(p.join(steamapps.path, 'common', app.folder))
              .create(recursive: true);
        }
      }
      return root.path;
    }

    test('манифест даёт точные id, название и папку', () async {
      final root = await makeSteam(
        'Steam',
        apps: [(id: 478980, title: 'Mansions of Madness', folder: 'Mansions')],
      );

      final apps = await SteamInstall.installed(roots: [root]);

      expect(apps, hasLength(1));
      expect(apps.single.appId, 478980);
      expect(apps.single.name, 'Mansions of Madness');
      expect(apps.single.installDir, endsWith(p.join('common', 'Mansions')));
    });

    // Вторая библиотека на другом диске — то, о чём человек чаще всего и
    // забывает, когда ищет папку с играми руками.
    test('библиотеки на других дисках тоже находятся', () async {
      final second = await makeSteam(
        'Второй диск',
        apps: [(id: 2, title: 'Вторая', folder: 'Вторая')],
      );
      final root = await makeSteam(
        'Steam',
        apps: [(id: 1, title: 'Первая', folder: 'Первая')],
        extraLibraries: [second],
      );

      final apps = await SteamInstall.installed(roots: [root]);

      expect(apps.map((a) => a.name), ['Вторая', 'Первая']);
    });

    // Манифест переживает удаление игры, и предлагать добавить то, чего на
    // диске нет, — худший вид услужливости.
    test('игра без папки на диске не предлагается', () async {
      final root = await makeSteam(
        'Steam',
        apps: [(id: 7, title: 'Удалённая', folder: 'Удалённая')],
        createFolders: false,
      );

      expect(await SteamInstall.installed(roots: [root]), isEmpty);
    });

    test('отсутствие Steam не роняет поиск', () async {
      final apps = await SteamInstall.installed(
        roots: [p.join(tmp.path, 'нет-такого')],
      );

      expect(apps, isEmpty);
    });

    test('одна и та же игра из двух библиотек не двоится', () async {
      final root = await makeSteam(
        'Steam',
        apps: [(id: 5, title: 'Одна', folder: 'Одна')],
      );

      final apps = await SteamInstall.installed(roots: [root, root]);

      expect(apps, hasLength(1));
    });
  });

  group('где искать игры', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_roots_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('библиотеки Steam попадают в список мест', () async {
      final root = Directory(p.join(tmp.path, 'Steam'));
      final steamapps = Directory(p.join(root.path, 'steamapps'));
      await Directory(p.join(steamapps.path, 'common')).create(recursive: true);
      await File(p.join(steamapps.path, 'libraryfolders.vdf')).writeAsString(
        '"libraryfolders"\n{\n\t"0"\n\t{\n'
        '\t\t"path"\t\t"${root.path}"\n\t}\n}\n',
      );

      final roots = await GameRoots.suggest(steamRoots: [root.path]);

      expect(
        roots.any(
          (r) =>
              r.kind == GameRootKind.steam &&
              r.path.endsWith(p.join('steamapps', 'common')),
        ),
        isTrue,
      );
    });

    // Место, которого нет, предлагать нельзя: человек нажмёт и получит
    // пустой список, не поняв почему.
    test('несуществующие места не предлагаются', () async {
      final roots = await GameRoots.suggest(
        steamRoots: [p.join(tmp.path, 'нет-такого')],
        installDir: p.join(tmp.path, 'тоже-нет'),
      );

      expect(
        roots.map((r) => r.path),
        isNot(contains(p.join(tmp.path, 'тоже-нет'))),
      );
    });

    test('папка загрузок приложения предлагается первой среди своих', () async {
      final games = Directory(p.join(tmp.path, 'Мои игры'));
      await games.create(recursive: true);

      final roots = await GameRoots.suggest(
        steamRoots: const [],
        installDir: games.path,
      );

      expect(roots.any((r) => r.path == games.path), isTrue);
    });

    test('одно и то же место не двоится', () async {
      final games = Directory(p.join(tmp.path, 'Игры'));
      await games.create(recursive: true);

      final roots = await GameRoots.suggest(
        steamRoots: const [],
        installDir: games.path,
      );

      expect(roots.where((r) => r.path == games.path), hasLength(1));
    });
  });
}
