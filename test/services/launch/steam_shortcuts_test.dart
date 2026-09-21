import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/binary_vdf.dart';
import 'package:evaporate/services/launch/steam_shortcuts.dart';
import 'package:evaporate/services/metadata/steam_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

void main() {
  late Directory tmp;
  late String steamRoot;
  late String configDir;
  late String shortcutsFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_steam_');
    steamRoot = p.join(tmp.path, 'Steam');
    configDir = p.join(steamRoot, 'userdata', '30629689', 'config');
    await Directory(configDir).create(recursive: true);
    shortcutsFile = p.join(configDir, 'shortcuts.vdf');
  });

  tearDown(() async {
    await deleteTempDir(tmp);
  });

  SteamShortcuts shortcuts({bool running = false}) =>
      SteamShortcuts(roots: [steamRoot], steamRunning: () async => running);

  /// Ярлык, который человек завёл сам, до нас.
  Map<String, Object> foreignEntry() => <String, Object>{
    'appid': -123456789,
    'AppName': 'Чужой ярлык',
    'Exe': r'"C:\Other\other.exe"',
    'StartDir': r'C:\Other\',
    'icon': '',
    'LaunchOptions': '-fullscreen',
    'tags': <String, Object>{'0': 'моё'},
  };

  Future<void> writeExisting(List<Map<String, Object>> entries) async {
    await File(shortcutsFile).writeAsBytes(
      BinaryVdf.encode(<String, Object>{
        'shortcuts': <String, Object>{
          for (var i = 0; i < entries.length; i++) '$i': entries[i],
        },
      }),
    );
  }

  Map<String, Object> readShortcuts() {
    final document = BinaryVdf.decode(File(shortcutsFile).readAsBytesSync());
    return document['shortcuts']! as Map<String, Object>;
  }

  Game gameWith({
    String id = 'g1',
    String title = 'Игра',
    String? cover,
    int? steamAppId,
  }) => Game(
    id: id,
    title: title,
    addedAt: DateTime.now(),
    installDir: p.join(tmp.path, 'games', 'игра'),
    executablePath: p.join(tmp.path, 'games', 'игра', 'game.exe'),
    details: GameDetails(coverPath: cover, steamAppId: steamAppId),
  );

  /// Имена файлов витрины для игры с этим id.
  ({String portrait, String capsule, String hero, String logo}) gridNames(
    String gameId,
  ) {
    final id = SteamShortcuts.appIdFor(gameId).toUnsigned(32);
    return (
      portrait: '${id}p.jpg',
      capsule: '$id.jpg',
      hero: '${id}_hero.jpg',
      logo: '${id}_logo.png',
    );
  }

  List<int> bytesOf(String name) =>
      File(p.join(configDir, 'grid', name)).readAsBytesSync();

  test('ярлык ложится в файл Steam, не трогая заведённые человеком', () async {
    await writeExisting([foreignEntry()]);

    await shortcuts().addGame(gameWith(title: 'Портальная игра'));

    final list = readShortcuts();
    expect(list, hasLength(2));

    // Чужая запись доехала со всеми своими полями, включая те, которых мы
    // сами не пишем: человеку это его ярлык, а не наш черновик.
    final foreign = list['0']! as Map<String, Object>;
    expect(foreign['AppName'], 'Чужой ярлык');
    expect(foreign['LaunchOptions'], '-fullscreen');
    expect(foreign['tags'], {'0': 'моё'});

    final ours = list['1']! as Map<String, Object>;
    expect(ours['AppName'], 'Портальная игра');
    expect(ours['Exe'], '"${p.join(tmp.path, 'games', 'игра', 'game.exe')}"');
  });

  // Steam кавычит `Exe`, но не `StartDir`, и рабочая папка у него с
  // завершающим разделителем. Отличие видно только на настоящем файле.
  test('путь берётся в кавычки, а рабочая папка — нет', () async {
    await shortcuts().addGame(gameWith());

    final ours = readShortcuts()['0']! as Map<String, Object>;
    expect(ours['Exe'], startsWith('"'));
    expect(ours['Exe'], endsWith('"'));
    expect(ours['StartDir'], isNot(startsWith('"')));
    expect(ours['StartDir'], endsWith(p.separator));
  });

  // Steam держит список в памяти и выкладывает его при выходе: наша запись
  // пропала бы молча, а человек решил бы, что кнопка не работает.
  test('при запущенном Steam ничего не пишется, а говорится вслух', () async {
    await writeExisting([foreignEntry()]);
    final before = File(shortcutsFile).readAsBytesSync();

    await expectLater(
      shortcuts(running: true).addGame(gameWith()),
      throwsA(isA<SteamShortcutException>()),
    );
    expect(File(shortcutsFile).readAsBytesSync(), before);
  });

  // Читаем мы, чтобы переписать. Не разобрали — значит, перепишем поверх
  // чужих ярлыков, и человек их не вернёт.
  test('нечитаемый список не переписывается, а отклоняется', () async {
    final broken = <int>[0, 115, 104, 0, 0x07, 65, 0, 1, 2, 3];
    await File(shortcutsFile).writeAsBytes(broken);

    await expectLater(
      shortcuts().addGame(gameWith()),
      throwsA(isA<SteamShortcutException>()),
    );
    expect(File(shortcutsFile).readAsBytesSync(), broken);
  });

  // В списке ярлыков ждём только карты. Прочее `addGame` выбрасывал при
  // переписывании — непонятое не трогают, а не теряют.
  test('непонятная запись в списке отклоняет правку, а не теряется', () async {
    final original = BinaryVdf.encode(<String, Object>{
      'shortcuts': <String, Object>{'0': foreignEntry(), '1': 'не карта'},
    });
    await File(shortcutsFile).writeAsBytes(original);

    await expectLater(
      shortcuts().addGame(gameWith()),
      throwsA(isA<SteamShortcutException>()),
    );
    expect(File(shortcutsFile).readAsBytesSync(), original);
  });

  // На macOS процесс Steam зовётся `steam_osx`: проверка по `steam` его не
  // видела, и запись в список при запущенном Steam молча пропадала.
  test('запущенный Steam ищется под своим именем на каждой системе', () {
    expect(SteamShortcuts.processNamesFor('macos'), contains('steam_osx'));
    expect(SteamShortcuts.processNamesFor('linux'), contains('steam'));
    expect(SteamShortcuts.processNamesFor('windows'), contains('steam.exe'));
  });

  test('повторное добавление правит запись, а не плодит двойников', () async {
    final service = shortcuts();
    await service.addGame(gameWith(title: 'Первое имя'));
    await service.addGame(gameWith(title: 'Второе имя'));

    final list = readShortcuts();
    expect(list, hasLength(1));
    expect((list['0']! as Map<String, Object>)['AppName'], 'Второе имя');
  });

  test('перед записью прежний список ложится рядом копией', () async {
    await writeExisting([foreignEntry()]);
    final before = File(shortcutsFile).readAsBytesSync();

    await shortcuts().addGame(gameWith());

    final backup = File('$shortcutsFile.evaporate.bak');
    expect(backup.existsSync(), isTrue);
    expect(backup.readAsBytesSync(), before);
  });

  test('список без файла заводится с нуля', () async {
    expect(File(shortcutsFile).existsSync(), isFalse);

    await shortcuts().addGame(gameWith());

    expect(readShortcuts(), hasLength(1));
  });

  test('игре без исполняемого файла ярлык не заводят', () async {
    final game = Game(id: 'g1', title: 'Игра', addedAt: DateTime.now());

    await expectLater(
      shortcuts().addGame(game),
      throwsA(isA<SteamShortcutException>()),
    );
  });

  test('без установленного Steam говорится, что его не нашли', () async {
    final service = SteamShortcuts(
      roots: [p.join(tmp.path, 'нет такого')],
      steamRunning: () async => false,
    );

    await expectLater(
      service.addGame(gameWith()),
      throwsA(isA<SteamShortcutException>()),
    );
  });

  test('из нескольких записей выбирается та, под которой сидели', () async {
    final second = p.join(steamRoot, 'userdata', '11111111', 'config');
    await Directory(second).create(recursive: true);
    File(p.join(steamRoot, 'config', 'loginusers.vdf'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
"users"
{
  "76561197971377189"
  {
    "AccountName"  "первый"
    "MostRecent"   "0"
  }
  "76561197990895417"
  {
    "AccountName"  "второй"
    "MostRecent"   "1"
  }
}
''');

    await shortcuts().addGame(gameWith());

    // 76561197990895417 - 76561197960265728 = 30629689.
    expect(File(shortcutsFile).existsSync(), isTrue);
    expect(File(p.join(second, 'shortcuts.vdf')).existsSync(), isFalse);
  });

  group('appid', () {
    test('не зависит от того, куда переставили игру', () {
      expect(SteamShortcuts.appIdFor('g1'), SteamShortcuts.appIdFor('g1'));
      expect(
        SteamShortcuts.appIdFor('g1'),
        isNot(SteamShortcuts.appIdFor('g2')),
      );
    });

    // Им Steam метит сторонние ярлыки; у его собственной записи он стоял.
    test('старший бит взведён, и число влезает в 32 знаковых', () {
      for (final id in ['g1', 'другая игра', 'x' * 200]) {
        final appId = SteamShortcuts.appIdFor(id);
        expect(appId.toUnsigned(32) & 0x80000000, 0x80000000);
        expect(appId, lessThan(0));
        expect(appId, greaterThanOrEqualTo(-2147483648));
      }
    });
  });

  group('обложка', () {
    /// Заголовок JPEG ровно до размеров — дальше разбор не идёт.
    List<int> jpeg({required int width, required int height}) => [
      0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, //
      height >> 8, height & 0xFF,
      width >> 8, width & 0xFF,
      0x03, 0x00,
    ];

    test('вертикальная ложится витриной, горизонтальная — плашкой', () {
      const appId = -797043768;
      const id = 3497923528;

      expect(
        SteamShortcuts.gridNameFor(appId, jpeg(width: 600, height: 900)),
        '${id}p.jpg',
      );
      expect(
        SteamShortcuts.gridNameFor(appId, jpeg(width: 460, height: 215)),
        '$id.jpg',
      );
    });

    test('неразобранная картинка считается вертикальной', () {
      // Каталог сначала просит вертикальную, поэтому догадка именно такая.
      expect(
        SteamShortcuts.gridNameFor(-1, const [1, 2, 3]),
        endsWith('p.jpg'),
      );
    });

    test('кладётся в grid рядом с ярлыком', () async {
      final cover = File(p.join(tmp.path, 'cover.jpg'));
      await cover.writeAsBytes(jpeg(width: 600, height: 900));

      await shortcuts().addGame(gameWith(cover: cover.path));

      final appId = SteamShortcuts.appIdFor('g1').toUnsigned(32);
      final placed = File(p.join(configDir, 'grid', '${appId}p.jpg'));
      expect(placed.existsSync(), isTrue);
      expect(placed.readAsBytesSync(), cover.readAsBytesSync());
    });

    test('пропавшая обложка не отменяет ярлык', () async {
      await shortcuts().addGame(
        gameWith(cover: p.join(tmp.path, 'нет-такой.jpg')),
      );

      expect(readShortcuts(), hasLength(1));
    });
  });

  group('витрина', () {
    // Одной вертикальной обложкой закрыта только сетка библиотеки: полка
    // «недавних» и страница игры остались бы пустыми, а по ним и видно
    // разницу между заведённой игрой и сиротой в списке.
    test('ложится всеми четырьмя картинками, а не одной', () async {
      await shortcuts().addGame(
        gameWith(),
        artwork: const SteamArtwork(
          portrait: [1, 1, 1],
          capsule: [2, 2, 2],
          hero: [3, 3, 3],
          logo: [4, 4, 4],
        ),
      );

      final names = gridNames('g1');
      expect(bytesOf(names.portrait), [1, 1, 1]);
      expect(bytesOf(names.capsule), [2, 2, 2]);
      expect(bytesOf(names.hero), [3, 3, 3]);
      expect(bytesOf(names.logo), [4, 4, 4]);
    });

    test('чего каталог не дал, того и не кладём', () async {
      await shortcuts().addGame(
        gameWith(),
        artwork: const SteamArtwork(hero: [3, 3, 3]),
      );

      final names = gridNames('g1');
      expect(bytesOf(names.hero), [3, 3, 3]);
      expect(File(p.join(configDir, 'grid', names.logo)).existsSync(), isFalse);
    });

    test('своя обложка не перетирает присланную каталогом', () async {
      final cover = File(p.join(tmp.path, 'своя.jpg'));
      await cover.writeAsBytes([9, 9, 9]);

      await shortcuts().addGame(
        gameWith(cover: cover.path),
        artwork: const SteamArtwork(portrait: [1, 1, 1]),
      );

      expect(bytesOf(gridNames('g1').portrait), [1, 1, 1]);
    });

    // Игра могла прийти не из Steam вовсе: одна обложка лучше пустой рамки.
    test('без витрины каталога в ход идёт своя обложка', () async {
      final cover = File(p.join(tmp.path, 'своя.jpg'));
      await cover.writeAsBytes([9, 9, 9]);

      await shortcuts().addGame(gameWith(cover: cover.path));

      expect(bytesOf(gridNames('g1').portrait), [9, 9, 9]);
    });
  });

  group('в библиотеке', () {
    /// Блок со своим Steam: настоящего на машине прогона нет.
    ({LibraryBloc library, SettingsBloc settings}) blocWith(
      SteamShortcuts service, {
      SteamCatalog? steam,
    }) {
      final paths = AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      );
      final settings = SettingsBloc(paths);
      final library = LibraryBloc(
        automaticMetadata: false,
        paths: paths,
        settings: settings,
        steamShortcuts: service,
        steam: steam,
      );
      addTearDown(() async {
        await library.close();
        await settings.close();
      });
      return (library: library, settings: settings);
    }

    test('событие заводит ярлык и говорит, что игра появится', () async {
      final blocs = blocWith(shortcuts());

      blocs.library.add(SteamShortcutRequested(gameWith(title: 'Портальная')));
      final state = await blocs.library.stream
          .firstWhere((s) => s.notice != null)
          .timeout(const Duration(seconds: 10));

      expect(state.notice!.isError, isFalse);
      expect(state.notice!.message, contains('Портальная'));
      expect(readShortcuts(), hasLength(1));
    });

    // Одной нашей обложкой закрыта одна створка из четырёх, а Steam рисовал
    // для этой игры все: незачем показывать своё, когда есть его.
    test('у игры с известным appid витрина берётся из каталога', () async {
      final asked = <String>[];
      final blocs = blocWith(
        shortcuts(),
        steam: SteamCatalog(
          fetch: (uri) async => fail('описание тут не спрашивают'),
          fetchImage: (uri) async {
            asked.add(uri.pathSegments.last);
            return [uri.pathSegments.last.length];
          },
        ),
      );

      blocs.library.add(SteamShortcutRequested(gameWith(steamAppId: 292030)));
      await blocs.library.stream
          .firstWhere((s) => s.notice != null)
          .timeout(const Duration(seconds: 10));

      expect(asked, [
        'library_600x900.jpg',
        'header.jpg',
        'library_hero.jpg',
        'logo.png',
      ]);
      final names = gridNames('g1');
      expect(bytesOf(names.portrait), ['library_600x900.jpg'.length]);
      expect(bytesOf(names.hero), ['library_hero.jpg'.length]);
      expect(bytesOf(names.logo), ['logo.png'.length]);
    });

    // Витрина — украшение, а ярлык — дело. Нет сети, нет картинок на CDN —
    // игра всё равно должна оказаться в Steam.
    test('недоступная витрина не отменяет ярлык', () async {
      final blocs = blocWith(
        shortcuts(),
        steam: SteamCatalog(
          fetch: (uri) async => fail('описание тут не спрашивают'),
          fetchImage: (uri) async => throw const SocketException('нет сети'),
        ),
      );

      blocs.library.add(SteamShortcutRequested(gameWith(steamAppId: 292030)));
      final state = await blocs.library.stream
          .firstWhere((s) => s.notice != null)
          .timeout(const Duration(seconds: 10));

      expect(state.notice!.isError, isFalse);
      expect(readShortcuts(), hasLength(1));
    });

    // Отказ обязан дойти до человека словами: иначе он увидит лишь то, что
    // игра в Steam не появилась, и решит, что кнопка сломана.
    test('запущенный Steam доходит сообщением, а не тишиной', () async {
      final blocs = blocWith(shortcuts(running: true));

      blocs.library.add(SteamShortcutRequested(gameWith()));
      final state = await blocs.library.stream
          .firstWhere((s) => s.notice != null)
          .timeout(const Duration(seconds: 10));

      expect(state.notice!.isError, isTrue);
      expect(File(shortcutsFile).existsSync(), isFalse);
    });
  });
}
