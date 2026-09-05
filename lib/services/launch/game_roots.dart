import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import 'steam_install.dart';

/// Откуда взялось место: подпись для показа собирается по этому признаку.
///
/// Признак, а не готовая строка: имена лончеров не переводятся, а «Том» и
/// «Диск» — переводятся, и собирать их вместе умеет только слой интерфейса
/// (`gameRootLabel`), у которого есть язык.
enum GameRootKind {
  steam,
  gog,
  epic,
  heroic,
  lutris,
  games,
  applications,
  appDownloads,
  volume,
  drive,
}

/// Место, где стоит поискать установленные игры.
class GameRoot {
  const GameRoot({required this.path, required this.kind, this.name});

  final String path;
  final GameRootKind kind;

  /// Имя тома или буква диска — то, чем один том отличается от другого.
  final String? name;
}

/// Где на этой машине обычно лежат установленные игры.
///
/// Человек не обязан помнить, в какой подпапке какой лончер держит свои
/// игры, — а места эти наперечёт. Такой же список для сохранений
/// `SavePathFinder` собирает давно; здесь то же самое для установок.
///
/// Библиотеки Steam берутся не из догадок, а из его собственных файлов,
/// поэтому находятся и заведённые на других дисках.
///
/// Домашние «Документы», «Рабочий стол» и «Загрузки» сюда намеренно не
/// попадают: на macOS обход каждой из них вызывает системный запрос прав,
/// которых человек не просил, а игр там почти не бывает.
class GameRoots {
  const GameRoots._();

  /// Все места, которые стоит предложить, — только существующие.
  static Future<List<GameRoot>> suggest({
    List<String>? steamRoots,
    String? installDir,
  }) async {
    final found = <String, GameRoot>{};

    void add(String path, GameRootKind kind, [String? name]) {
      if (path.isEmpty) return;
      final key = p.normalize(path);
      found.putIfAbsent(key, () => GameRoot(path: key, kind: kind, name: name));
    }

    for (final steamapps in await SteamInstall.libraries(roots: steamRoots)) {
      add(p.join(steamapps, 'common'), GameRootKind.steam);
    }

    final home = AppPaths.home;
    if (Platform.isWindows) {
      add(r'C:\GOG Games', GameRootKind.gog);
      add(r'C:\Program Files\Epic Games', GameRootKind.epic);
      add(p.join(home, 'Games'), GameRootKind.games);
    } else if (Platform.isMacOS) {
      add('/Applications', GameRootKind.applications);
      add(p.join(home, 'Applications'), GameRootKind.applications);
      add(p.join(home, 'Games'), GameRootKind.games);
    } else {
      add(p.join(home, 'Games'), GameRootKind.games);
      add(p.join(home, 'GOG Games'), GameRootKind.gog);
      // Heroic и Lutris держат игры у себя, каждый по-своему.
      add(
        p.join(
          home,
          '.var',
          'app',
          'com.heroicgameslauncher.hgl',
          'config',
          'heroic',
          'Games',
        ),
        GameRootKind.heroic,
      );
      add(p.join(home, 'Games', 'Heroic'), GameRootKind.heroic);
      add(p.join(home, 'Games', 'lutris'), GameRootKind.lutris);
    }

    // Папка, куда качает само приложение, — самая вероятная из всех.
    if (installDir != null) add(installDir, GameRootKind.appDownloads);

    for (final volume in await _volumes()) {
      add(volume.path, volume.kind, volume.name);
    }

    final result = <GameRoot>[];
    for (final root in found.values) {
      if (await Directory(root.path).exists()) result.add(root);
    }
    return result;
  }

  /// Подключённые тома, кроме системного.
  ///
  /// Игры чаще всего и живут на отдельном диске: они большие, а системный
  /// раздел маленький.
  static Future<List<GameRoot>> _volumes() async {
    final roots = <GameRoot>[];
    if (Platform.isMacOS) {
      await _addChildren(Directory('/Volumes'), roots);
    } else if (Platform.isLinux) {
      final user = Platform.environment['USER'];
      if (user != null) {
        await _addChildren(Directory(p.join('/media', user)), roots);
      }
      await _addChildren(Directory('/mnt'), roots);
    } else {
      // Перебрать буквы дешевле, чем спрашивать систему: их всего два
      // десятка, а проверка существования папки почти бесплатна.
      for (
        var letter = 'D'.codeUnitAt(0);
        letter <= 'Z'.codeUnitAt(0);
        letter++
      ) {
        final drive = '${String.fromCharCode(letter)}:\\';
        if (await Directory(drive).exists()) {
          roots.add(
            GameRoot(
              path: drive,
              kind: GameRootKind.drive,
              name: String.fromCharCode(letter),
            ),
          );
        }
      }
    }
    return roots;
  }

  static Future<void> _addChildren(Directory dir, List<GameRoot> out) async {
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        out.add(
          GameRoot(path: entity.path, kind: GameRootKind.volume, name: name),
        );
      }
    } on FileSystemException {
      // Список томов — подсказка, а не обязанность.
    }
  }
}
