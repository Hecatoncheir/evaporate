import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/save_path_template.dart';
import '../../models/save_profile.dart';

class SavePathSuggestion {
  const SavePathSuggestion({
    required this.path,
    required this.template,
    required this.label,
    required this.score,
    this.fileCount = 0,
  });

  final String path;

  /// Переносимый шаблон — именно он попадёт в профиль игры.
  final String template;
  final String label;
  final int score;
  final int fileCount;
}

/// Ищет папку сохранений по названию игры в местах, где игры их обычно держат.
///
/// Это догадка, а не истина: пользователь подтверждает выбор в UI.
class SavePathFinder {
  ///
  /// [searchRoots] подменяет системные корни — иначе поиск проверялся бы
  /// только на содержимом настоящей домашней папки.
  static Future<List<SavePathSuggestion>> suggest(
    String gameTitle, {
    @visibleForTesting List<String>? searchRoots,
  }) async {
    final needle = _normalize(gameTitle);
    if (needle.isEmpty) return const [];

    final roots = searchRoots == null
        ? _roots()
        : [
            for (final path in searchRoots)
              _Root(token: SavePathTemplate.home, path: path, depth: 1),
          ];

    final results = <String, SavePathSuggestion>{};
    for (final root in roots) {
      await _scanRoot(root, needle, gameTitle, results);
    }

    final list = results.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(12).toList();
  }

  static List<_Root> _roots() {
    final placeholders = SavePathTemplate.placeholders;
    final roots = <_Root>[];

    void add(String token, [List<String> subPaths = const []]) {
      final base = placeholders[token];
      if (base == null) return;
      roots.add(_Root(token: token, path: base, depth: 1));
      for (final sub in subPaths) {
        roots.add(
          _Root(
            token: token,
            path: p.join(base, sub.replaceAll('/', p.separator)),
            depth: 1,
            suffix: sub,
          ),
        );
      }
    }

    add(SavePathTemplate.appSupport);
    add(SavePathTemplate.documents, ['My Games', 'Saved Games', 'Games']);
    add(SavePathTemplate.savedGames);
    if (Platform.isWindows) {
      add(SavePathTemplate.localAppData);
    }
    if (Platform.isLinux) {
      final home = placeholders[SavePathTemplate.home];
      if (home != null) {
        roots.add(
          _Root(
            token: SavePathTemplate.home,
            path: p.join(home, '.config'),
            depth: 1,
            suffix: '.config',
          ),
        );
      }
    }
    return roots;
  }

  static Future<void> _scanRoot(
    _Root root,
    String needle,
    String gameTitle,
    Map<String, SavePathSuggestion> out,
  ) async {
    final dir = Directory(root.path);
    if (!await dir.exists()) return;

    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }

    for (final entity in entities) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      final score = _match(_normalize(name), needle);
      if (score <= 0) continue;

      final fileCount = await _countFiles(entity);
      if (fileCount == 0) continue;

      out[entity.path] = SavePathSuggestion(
        path: entity.path,
        template: SavePathTemplate.collapse(entity.path),
        label: SavePathRule.defaultLabel,
        score: score + (root.suffix != null ? 15 : 0),
        fileCount: fileCount,
      );
    }
  }

  /// Совпадение имени папки с названием игры: точное, вхождение, по словам.
  static int _match(String candidate, String needle) {
    if (candidate.isEmpty) return 0;
    if (candidate == needle) return 100;
    if (candidate.contains(needle) || needle.contains(candidate)) {
      final shorter = candidate.length < needle.length ? candidate : needle;
      // Совпадения по двум-трём буквам ничего не значат.
      return shorter.length >= 4 ? 70 : 0;
    }

    final words = needle
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
    if (words.isEmpty) return 0;
    final matched = words.where(candidate.contains).length;
    if (matched == words.length) return 55;
    if (matched > 0 && words.length > 1) return 30;
    return 0;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-я0-9\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Future<int> _countFiles(Directory dir, {int limit = 200}) async {
    var count = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          count++;
          if (count >= limit) break;
        }
      }
    } on FileSystemException {
      return count;
    }
    return count;
  }
}

class _Root {
  const _Root({
    required this.token,
    required this.path,
    required this.depth,
    this.suffix,
  });

  final String token;
  final String path;
  final int depth;
  final String? suffix;
}
