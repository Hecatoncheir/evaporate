import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import 'vdf.dart';

/// Игра, установленная Steam на этой машине.
class SteamApp {
  const SteamApp({
    required this.appId,
    required this.name,
    required this.installDir,
  });

  /// Точный идентификатор — не догадка по названию.
  final int appId;

  /// Название, как его знает сам Steam.
  final String name;

  /// Куда игра поставлена.
  final String installDir;
}

/// Что Steam знает о своих играх на этой машине.
///
/// Приложение спрашивало у Steam по сети и **по названию**: очищало имя
/// папки и искало похожее с порогом схожести. Между тем точный ответ лежит
/// на диске, в файлах самого Steam, и достаётся без сети:
///
/// * `steamapps/libraryfolders.vdf` — все библиотеки, включая те, что на
///   других дисках, о которых пользователь и сам мог забыть;
/// * `steamapps/appmanifest_<appid>.acf` — точные `appid`, название и папка.
///
/// Точный `appid` тут важнее найденных папок. По нему ищутся пути
/// сохранений, и код каталога прямо оговаривает почему: «совпадение
/// названия другой игры не должно подставлять чужие сохранения». Пока
/// идентификатор добывался нечётким сравнением, эта оговорка защищала лишь
/// наполовину.
///
/// Каталога содержимого в приложении по-прежнему нет: читаются файлы на
/// диске самого игрока, ничего не скачивается и никуда не отправляется.
class SteamInstall {
  const SteamInstall._();

  /// Где Steam держит себя на каждой из систем.
  ///
  /// Подменяется в тестах: настоящая установка есть не на всякой машине, а
  /// прогон идёт на трёх.
  static List<String> defaultRoots() {
    final home = AppPaths.home;
    if (Platform.isMacOS) {
      return [p.join(home, 'Library', 'Application Support', 'Steam')];
    }
    if (Platform.isWindows) {
      return [
        r'C:\Program Files (x86)\Steam',
        r'C:\Program Files\Steam',
        p.join(home, 'Steam'),
      ];
    }
    return [
      p.join(home, '.local', 'share', 'Steam'),
      p.join(home, '.steam', 'steam'),
      // Flatpak держит своё хозяйство отдельно.
      p.join(home, '.var', 'app', 'com.valvesoftware.Steam', 'data', 'Steam'),
    ];
  }

  /// Все папки библиотек Steam, включая заведённые на других дисках.
  static Future<List<String>> libraries({List<String>? roots}) async {
    final found = <String>{};
    for (final root in roots ?? defaultRoots()) {
      final steamapps = Directory(p.join(root, 'steamapps'));
      if (!await steamapps.exists()) continue;
      found.add(steamapps.path);

      final file = File(p.join(steamapps.path, 'libraryfolders.vdf'));
      if (!await file.exists()) continue;
      final String text;
      try {
        text = await file.readAsString();
      } on FileSystemException {
        continue;
      }
      final folders = Vdf.map(Vdf.parse(text), ['libraryfolders']);
      if (folders == null) continue;
      for (final entry in folders.values) {
        if (entry is! Map<String, Object>) continue;
        final path = entry['path'];
        if (path is! String || path.isEmpty) continue;
        final dir = Directory(p.join(path, 'steamapps'));
        if (await dir.exists()) found.add(dir.path);
      }
    }
    return found.toList();
  }

  /// Установленные игры со всеми их точными сведениями.
  ///
  /// Игры без папки на диске пропускаются: манифест переживает удаление, и
  /// предлагать добавить то, чего нет, — худший вид услужливости.
  static Future<List<SteamApp>> installed({List<String>? roots}) async {
    final apps = <int, SteamApp>{};

    for (final steamapps in await libraries(roots: roots)) {
      final List<FileSystemEntity> entries;
      try {
        entries = await Directory(steamapps).list(followLinks: false).toList();
      } on FileSystemException {
        continue;
      }

      for (final entity in entries) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('appmanifest_') || !name.endsWith('.acf')) {
          continue;
        }
        final app = await _readManifest(entity, steamapps);
        if (app != null) apps[app.appId] = app;
      }
    }

    final list = apps.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<SteamApp?> _readManifest(File file, String steamapps) async {
    final String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      return null;
    }
    final doc = Vdf.parse(text);
    final appId = int.tryParse(Vdf.string(doc, ['AppState', 'appid']) ?? '');
    final name = Vdf.string(doc, ['AppState', 'name']);
    final folder = Vdf.string(doc, ['AppState', 'installdir']);
    if (appId == null || name == null || folder == null) return null;
    if (name.isEmpty || folder.isEmpty) return null;

    final installDir = p.join(steamapps, 'common', folder);
    if (!await Directory(installDir).exists()) return null;

    return SteamApp(appId: appId, name: name, installDir: installDir);
  }

  /// Игры по папке установки — так найденное на диске сопоставляется с тем,
  /// что о нём знает Steam.
  static Map<String, SteamApp> byInstallDir(Iterable<SteamApp> apps) => {
    for (final app in apps) p.normalize(app.installDir): app,
  };
}
