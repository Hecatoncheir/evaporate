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
  /// дело: человек не обязан помнить, в какой подпапке лежат игры.
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

    final found = <ScannedGame>[];
    await _collect(
      root,
      existingDirs.map(p.normalize).toSet(),
      found,
      limit,
      containerDepth,
      steamApps,
      isCancelled ?? _never,
      onDirectory,
    );

    found.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return found;
  }

  static Future<void> _collect(
    Directory dir,
    Set<String> existing,
    List<ScannedGame> out,
    int limit,
    int depthLeft,
    Map<String, SteamApp> steamApps,
    bool Function() isCancelled,
    void Function(String directory)? onDirectory,
  ) async {
    if (isCancelled()) return;
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      // Папка без прав доступа — не повод обрывать весь обход.
      return;
    }

    for (final entity in entries) {
      if (out.length >= limit || isCancelled()) return;
      if (entity is! Directory) continue;

      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (_skip.contains(name.toLowerCase())) continue;
      if (existing.contains(p.normalize(entity.path))) continue;

      // О папке сообщаем до её осмотра: он и есть самая долгая часть, и
      // человек должен видеть, на чём приложение сейчас стоит.
      onDirectory?.call(entity.path);
      final verdict = await _classify(entity);
      if (isCancelled()) return;
      switch (verdict.kind) {
        case _Kind.nothing:
          continue;
        case _Kind.container:
          if (depthLeft > 0) {
            await _collect(
              entity,
              existing,
              out,
              limit,
              depthLeft - 1,
              steamApps,
              isCancelled,
              onDirectory,
            );
          }
        case _Kind.game:
          // Если игру знает Steam, берём его название и идентификатор: они
          // точные, а имя папки — в лучшем случае догадка.
          final known = steamApps[p.normalize(entity.path)];
          final cleaned = ReleaseName.clean(name);
          out.add(
            ScannedGame(
              title: known?.name ?? (cleaned.isEmpty ? name : cleaned),
              installDir: entity.path,
              executablePath: verdict.executable!,
              steamAppId: known?.appId,
            ),
          );
      }
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
