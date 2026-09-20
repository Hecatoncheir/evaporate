import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/save_path_template.dart';
import '../../models/save_profile.dart';
import 'folder_match.dart';
import 'save_path_finder.dart';

/// Ищет папку сохранений по следам работы игры.
///
/// База путей знает не всё: половина библиотеки торрент-лончера в неё не
/// попадала никогда — свежие релизы, малоизвестные вещи, всё, что мимо Steam.
/// Зато игра сама создаёт себе папку под сейвы, и приложение знает точный
/// промежуток, когда она работала. Что изменилось в этот промежуток — и есть
/// ответ, причём не догадка, а наблюдение.
///
/// Найденное показывают человеку, а не записывают молча: рядом с сейвами игра
/// пишет логи, кэш шейдеров и телеметрию, и отличить одно от другого
/// наверняка нельзя.
class SaveActivityWatch {
  const SaveActivityWatch._();

  /// Папки, которые меняются у всех и никогда не про сохранения.
  static const _noise = {
    'cache',
    'caches',
    'cachestorage',
    'code cache',
    'gpucache',
    'shadercache',
    'shader_cache',
    'dxcache',
    'logs',
    'log',
    'crashes',
    'crashdumps',
    'crashreports',
    'dumps',
    'temp',
    'tmp',
    'telemetry',
    'analytics',
    'webcache',
    'cookies',
    'local storage',
    'session storage',
    'servicecache',
    'blob_storage',
    'updates',
    'downloads',
  };

  /// Расширения, которые чаще принадлежат сохранению, чем чему-то ещё.
  static const _saveLike = {
    '.sav',
    '.save',
    '.savegame',
    '.slot',
    '.profile',
    '.dat',
    '.bin',
    '.sl2',
    '.ess',
    '.es3',
    '.rpgsave',
    '.db',
    '.json',
    '.xml',
  };

  /// Глубина обхода внутри каждой папки-кандидата. Три уровня накрывают
  /// `Игра/Профиль/Слот`, а дальше начинаются чужие деревья.
  static const _depth = 3;

  /// Сколько файлов смотреть в одной папке. Кэш на десятки тысяч файлов
  /// разбирать незачем: он всё равно не сохранение.
  static const _fileBudget = 400;

  /// Что изменилось с момента [since].
  ///
  /// [gameDir] осматривается тоже и весит больше прочего: игры, поставленные
  /// этим лончером, чаще всего пишут сейвы прямо к себе.
  static Future<List<SavePathSuggestion>> changedSince(
    DateTime since, {
    required String gameTitle,
    String? gameDir,
    List<SaveRoot>? roots,
  }) async {
    final found = <String, SavePathSuggestion>{};
    final needle = FolderMatch.normalize(gameTitle);

    for (final root in roots ?? SavePathFinder.roots()) {
      await _scan(root, since, needle, gameDir, found);
    }
    if (gameDir != null && gameDir.isNotEmpty) {
      await _scan(
        SaveRoot(path: gameDir, insideKnownGamesFolder: false),
        since,
        needle,
        gameDir,
        found,
      );
    }

    final list = found.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(8).toList();
  }

  static Future<void> _scan(
    SaveRoot root,
    DateTime since,
    String needle,
    String? gameDir,
    Map<String, SavePathSuggestion> out,
  ) async {
    final dir = Directory(root.path);
    if (!await dir.exists()) return;

    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      // Папка без прав доступа — не повод обрывать весь обход.
      return;
    }

    for (final entry in entries) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (name.startsWith('.')) continue;
      if (_noise.contains(name.toLowerCase())) continue;
      if (out.containsKey(entry.path)) continue;

      final touched = await _touchedFiles(entry, since);
      if (touched.count == 0) continue;

      final score = _score(
        name: name,
        needle: needle,
        touched: touched,
        insideGame: gameDir != null && p.isWithin(gameDir, entry.path),
        insideKnownGamesFolder: root.insideKnownGamesFolder,
      );
      if (score <= 0) continue;

      out[entry.path] = SavePathSuggestion(
        path: entry.path,
        template: SavePathTemplate.collapse(entry.path, gameDir: gameDir),
        label: SavePathRule.defaultLabel,
        origin: SavePathOrigin.watch,
        score: score,
        fileCount: touched.count,
      );
    }
  }

  /// Сколько файлов в папке тронуто после [since] и похожи ли они на сейвы.
  static Future<_Touched> _touchedFiles(Directory dir, DateTime since) async {
    var count = 0;
    var saveLike = false;
    var seen = 0;
    final rootDepth = p.split(dir.path).length;

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (++seen > _fileBudget) break;
        if (!await _touchedAfter(entity, since, rootDepth: rootDepth)) continue;

        count++;
        if (_saveLike.contains(p.extension(entity.path).toLowerCase())) {
          saveLike = true;
        }
      }
    } on FileSystemException {
      // До конца обойти не вышло — судим по тому, что успели увидеть.
    }
    return _Touched(
      count: count,
      saveLike: saveLike,
      truncated: seen > _fileBudget,
    );
  }

  /// Считается ли этот файл тронутым за время работы игры.
  ///
  /// Три отказа подряд, и каждый о своём: папки не в счёт; глубже
  /// нескольких уровней сейвы не прячут, а обход дорожает; нечитаемый
  /// файл о прогрессе ничего не говорит.
  static Future<bool> _touchedAfter(
    FileSystemEntity entity,
    DateTime since, {
    required int rootDepth,
  }) async {
    if (entity is! File) return false;
    if (p.split(entity.path).length - rootDepth > _depth) return false;

    final stat = await _statOrNull(entity);
    return stat != null && !stat.modified.isBefore(since);
  }

  /// Сведения о файле; null — прочитать не вышло, и такой файл не в счёт.
  static Future<FileStat?> _statOrNull(File file) async {
    try {
      return await file.stat();
    } on FileSystemException {
      return null;
    }
  }

  static int _score({
    required String name,
    required String needle,
    required _Touched touched,
    required bool insideGame,
    required bool insideKnownGamesFolder,
  }) {
    final byName = FolderMatch.score(FolderMatch.normalize(name), needle);

    // Одного лишь `.sav` внутри мало: расширение встречается у чего угодно, и
    // без этой проверки в подсказки попала бы любая посторонняя папка,
    // тронутая за время игры. Нужен хотя бы один настоящий повод: имя,
    // похожее на название, папка самой игры или заведомо игровое место
    // вроде «My Games» — туда чужое не пишут.
    if (byName == 0 && !insideGame && !insideKnownGamesFolder) return 0;

    var score = byName;
    if (insideGame) score += 45;
    if (insideKnownGamesFolder) score += 25;
    if (touched.saveLike) score += 25;
    // Папка, куда за сеанс насыпало сотни файлов, — это кэш, а не сейв.
    if (touched.truncated) score -= 45;
    return score;
  }
}

class _Touched {
  const _Touched({
    required this.count,
    required this.saveLike,
    required this.truncated,
  });

  final int count;
  final bool saveLike;

  /// Файлов оказалось больше, чем мы согласились смотреть.
  final bool truncated;
}
