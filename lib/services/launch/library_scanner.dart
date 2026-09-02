import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/game.dart';
import 'executable_finder.dart';

/// Найденная в папке игра, ещё не добавленная в библиотеку.
class ScannedGame {
  const ScannedGame({
    required this.title,
    required this.installDir,
    required this.executablePath,
  });

  /// Название берётся из имени папки: другого источника на диске нет.
  final String title;
  final String installDir;
  final String executablePath;
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
  static Future<List<ScannedGame>> scan(
    String rootDir, {
    Set<String> existingDirs = const {},
    int limit = 200,
  }) async {
    final root = Directory(rootDir);
    if (!await root.exists()) return const [];

    final normalizedExisting = existingDirs
        .map((dir) => p.normalize(dir))
        .toSet();
    final found = <ScannedGame>[];

    await for (final entity in root.list(followLinks: false)) {
      if (found.length >= limit) break;
      if (entity is! Directory) continue;

      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (_skip.contains(name.toLowerCase())) continue;
      if (normalizedExisting.contains(p.normalize(entity.path))) continue;

      // Ищем неглубоко: игра лежит в своей папке, а не в дереве из десяти
      // уровней, зато обход сорока папок должен оставаться быстрым.
      final candidates = await ExecutableFinder.scan(
        entity.path,
        maxDepth: 3,
        limit: 5,
      );
      if (candidates.isEmpty) continue;

      found.add(
        ScannedGame(
          title: name,
          installDir: entity.path,
          executablePath: candidates.first.path,
        ),
      );
    }

    found.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return found;
  }

  /// Папки, уже занятые играми библиотеки.
  static Set<String> installedDirs(Iterable<Game> games) => {
    for (final game in games)
      if (game.installDir != null) game.installDir!,
  };
}
