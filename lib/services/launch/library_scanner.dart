import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/game.dart';
import '../metadata/release_name.dart';
import 'executable_finder.dart';
import 'steam_install.dart';

/// Найденная в папке игра, ещё не добавленная в библиотеку.
class ScannedGame {
  const ScannedGame({
    required this.title,
    required this.installDir,
    required this.executablePath,
    this.steamAppId,
    this.confident = true,
  });

  /// Название игры.
  ///
  /// Обычно из имени папки, очищенного от версий и меток релиз-групп: у
  /// репаков она называется `Hollow.Knight.v1.5.78-GOG`, и это же имя
  /// уезжало бы дальше в поиск метаданных. Если игру опознал Steam,
  /// название берётся у него — оно точное.
  final String title;
  final String installDir;
  final String executablePath;

  /// Точный идентификатор Steam, если игру опознали по его манифесту.
  final int? steamAppId;

  /// Уверены ли мы, что это игра.
  ///
  /// Обход папок с играми уверен: раз папка лежит среди игр и в ней есть
  /// исполняемый файл, это игра. А реестр Windows знает вообще всё
  /// установленное — браузеры, драйверы, — и отсеять их наверняка нельзя.
  /// Неуверенное предлагается, но галочкой заранее не отмечается.
  final bool confident;
}

/// Поиск уже установленных игр в одной папке.
///
/// Добавлять по одной — терпимо для трёх игр и мучительно для сорока.
/// Здесь мы обходим подпапки и считаем игрой ту, в которой нашёлся
/// исполняемый файл: другого признака у папки на диске нет.
class LibraryScanner {
  const LibraryScanner._();

  /// Папки, которые заведомо не игры: в них лежит служебное.
  static const _skip = {
    'saves',
    'savegames',
    'screenshots',
    'redist',
    'redistributables',
    '_commonredist',
    'directx',
    'temp',
    'tmp',
  };

  /// Обходит [rootDir] и возвращает подпапки, похожие на установленные игры.
  ///
  /// [existingDirs] — папки, уже известные библиотеке: их пропускаем, чтобы
  /// повторное сканирование не предлагало добавить то же самое.
  ///
  /// [containerDepth] — на сколько уровней спускаться внутрь папок, которые
  /// оказались не играми, а собраниями игр. Указать диск целиком — обычное
  static Future<List<ScannedGame>> scan(
    String rootDir, {
    Set<String> existingDirs = const {},
    int limit = 200,
    int containerDepth = 3,
    Map<String, SteamApp> steamApps = const {},
    bool Function()? isCancelled,
    void Function(String directory)? onDirectory,
  }) async {
    final root = Directory(rootDir);
    if (!await root.exists()) return const [];

    final walk = _Walk(
      existing: existingDirs.map(p.normalize).toSet(),
      limit: limit,
      steamApps: steamApps,
      isCancelled: isCancelled ?? _never,
      onDirectory: onDirectory,
    );
    await _collect(root, walk, containerDepth);

    walk.found.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return walk.found;
  }

  /// Обходит подпапки [dir] и складывает найденное в [walk].
  ///
  /// [depthLeft] — сколько уровней ещё можно спуститься внутрь папок,
  /// оказавшихся собраниями игр.
  static Future<void> _collect(Directory dir, _Walk walk, int depthLeft) async {
    if (walk.stopped) return;

    for (final entity in await _childrenOf(dir)) {
      if (walk.stopped) return;
      if (entity is! Directory || walk.skips(entity)) continue;

      // О папке сообщаем до её осмотра: он и есть самая долгая часть, и
      // человек должен видеть, на чём приложение сейчас стоит.
      walk.onDirectory?.call(entity.path);
      final verdict = await _classify(entity);
      if (walk.isCancelled()) return;

      switch (verdict.kind) {
        case _Kind.nothing:
          continue;
        case _Kind.container:
          if (depthLeft > 0) await _collect(entity, walk, depthLeft - 1);
        case _Kind.game:
          walk.add(entity, verdict.executable!);
      }
    }
  }

  /// Содержимое папки. Папка без прав доступа — не повод обрывать весь
  /// обход, поэтому вместо ошибки возвращается пустой список.
  static Future<List<FileSystemEntity>> _childrenOf(Directory dir) async {
    try {
      return await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return const [];
    }
  }

  /// Игра это, собрание игр или вообще ничего.
  ///
  /// Различить их одним признаком нельзя. У игры движка Unreal исполняемый
  /// файл лежит в `Binaries/Win64`, то есть глубоко, — и спускаться туда
  /// нельзя, игра это папка целиком. А `D:\Games` снаружи выглядит так же:
  /// исполняемые файлы тоже не на виду.
  ///
  /// Разводит их то, **сколько разных подпапок** содержат исполняемые файлы.
  /// У игры такая подпапка одна, у собрания их столько же, сколько игр.
  /// Единственный спорный случай — собрание из одной игры; его выдаёт
  /// отсутствие файлов рядом: у игры в корне всегда что-нибудь лежит, у
  /// собрания — только папки.
  static Future<_Verdict> _classify(Directory dir) async {
    // Предел выше, чем нужно для ответа: подпапки считаются по уже
    // найденному, и второй обход ради этого был бы лишним.
    final candidates = await ExecutableFinder.scan(
      dir.path,
      maxDepth: 3,
      limit: 24,
    );
    if (candidates.isEmpty) return _nothing;

    List<String> parts(ExecutableCandidate c) =>
        p.split(p.relative(c.path, from: dir.path));

    // Исполняемый файл прямо в папке — дальше можно не думать.
    for (final candidate in candidates) {
      if (parts(candidate).length == 1) {
        return (kind: _Kind.game, executable: candidate.path);
      }
    }

    final subdirs = {for (final c in candidates) parts(c).first};
    if (subdirs.length >= 2) return _container;

    final looseFiles = await dir
        .list(followLinks: false)
        .any((e) => e is File && !p.basename(e.path).startsWith('.'));
    if (!looseFiles) return _container;

    return (kind: _Kind.game, executable: candidates.first.path);
  }

  /// Осматривает одну папку: игра ли это.
  ///
  /// Нужно записям реестра Windows: там указана сама папка игры, а не место,
  /// где её искать, — обходить её детей незачем.
  static Future<ScannedGame?> inspect(
    String directory, {
    required String title,
    Set<String> existingDirs = const {},
    Map<String, SteamApp> steamApps = const {},
    bool confident = true,
  }) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return null;
    if (existingDirs.map(p.normalize).contains(p.normalize(directory))) {
      return null;
    }

    final verdict = await _classify(dir);
    if (verdict.kind != _Kind.game) return null;

    return _describe(
      directory: directory,
      name: title,
      executable: verdict.executable!,
      steamApps: steamApps,
      confident: confident,
    );
  }

  /// Собирает найденную игру из папки и того, что о ней знает Steam.
  ///
  /// Если игру знает Steam, берём его название и идентификатор: они
  /// точные, а имя папки — в лучшем случае догадка. Одно на оба пути
  /// поиска: осмотр одной папки и обход дерева должны звать одну и ту же
  /// игру одинаково.
  static ScannedGame _describe({
    required String directory,
    required String name,
    required String executable,
    required Map<String, SteamApp> steamApps,
    bool confident = true,
  }) {
    final known = steamApps[p.normalize(directory)];
    final cleaned = ReleaseName.clean(name);
    return ScannedGame(
      title: known?.name ?? (cleaned.isEmpty ? name : cleaned),
      installDir: directory,
      executablePath: executable,
      steamAppId: known?.appId,
      confident: confident,
    );
  }

  static bool _never() => false;

  /// Папки, уже занятые играми библиотеки.
  static Set<String> installedDirs(Iterable<Game> games) => {
    for (final game in games)
      if (game.installDir != null) game.installDir!,
  };
}

/// Чем оказалась осмотренная папка.
enum _Kind { game, container, nothing }

typedef _Verdict = ({_Kind kind, String? executable});

const _Verdict _container = (kind: _Kind.container, executable: null);
const _Verdict _nothing = (kind: _Kind.nothing, executable: null);

/// Условия одного обхода и то, что он уже нашёл.
///
/// Восемь аргументов, которые `_collect` передавал самому себе на каждый
/// уровень вложенности, — верный способ однажды перепутать два соседних
/// числа местами.
class _Walk {
  _Walk({
    required this.existing,
    required this.limit,
    required this.steamApps,
    required this.isCancelled,
    this.onDirectory,
  });

  /// Папки, уже известные библиотеке: повторный обход не должен предлагать
  /// добавить то же самое.
  final Set<String> existing;

  /// Сколько игр набирать. Обход диска целиком иначе не кончился бы.
  final int limit;
  final Map<String, SteamApp> steamApps;
  final bool Function() isCancelled;
  final void Function(String directory)? onDirectory;

  final found = <ScannedGame>[];

  /// Набрали сколько просили или обход отменили — дальше идти незачем.
  bool get stopped => found.length >= limit || isCancelled();

  /// Папки, в которые заходить не станем: скрытые, служебные и те, что уже
  /// заняты играми библиотеки.
  bool skips(Directory dir) {
    final name = p.basename(dir.path);
    return name.startsWith('.') ||
        LibraryScanner._skip.contains(name.toLowerCase()) ||
        existing.contains(p.normalize(dir.path));
  }

  void add(Directory dir, String executable) {
    found.add(
      LibraryScanner._describe(
        directory: dir.path,
        name: p.basename(dir.path),
        executable: executable,
        steamApps: steamApps,
      ),
    );
  }
}
