import 'dart:io';

import 'package:path/path.dart' as p;

import '../metadata/release_name.dart';

class ExecutableCandidate {
  const ExecutableCandidate({
    required this.path,
    required this.name,
    required this.score,
    this.sizeBytes = 0,
  });

  final String path;
  final String name;

  /// Чем выше, тем вероятнее, что это и есть игра.
  final int score;
  final int sizeBytes;
}

/// После распаковки торрента пользователь не должен вручную искать exe
/// в трёх уровнях вложенности — предлагаем кандидатов сами.
class ExecutableFinder {
  static const _junkMarkers = [
    'unins',
    'setup',
    'redist',
    'vcredist',
    'directx',
    'dxsetup',
    'crashhandler',
    'crashreport',
    'ueprereqsetup',
    'dotnet',
    'installer',
    'updater',
    // Нынешние спутники игр: защиты, служебные утилиты и всё, что кладут
    // рядом «на всякий случай».
    'easyanticheat',
    'battleye',
    'crashpad',
    'crashreporter',
    'ffmpeg',
    'python',
    '7z',
    'quicksfv',
    'directx_',
  ];

  static Future<List<ExecutableCandidate>> scan(
    String rootDir, {
    int maxDepth = 4,
    int limit = 40,
  }) async {
    final root = Directory(rootDir);
    if (!await root.exists()) return const [];

    final candidates = <ExecutableCandidate>[];
    await _walk(root, p.basename(rootDir), 0, maxDepth, candidates);

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.sizeBytes.compareTo(a.sizeBytes);
    });
    return candidates.take(limit).toList();
  }

  static Future<void> _walk(
    Directory dir,
    String folderName,
    int depth,
    int maxDepth,
    List<ExecutableCandidate> out,
  ) async {
    if (depth > maxDepth) return;
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        // На macOS .app — это папка, но для нас это единица запуска.
        if (Platform.isMacOS && name.endsWith('.app')) {
          out.add(
            ExecutableCandidate(
              path: entity.path,
              name: name,
              score: _score(name, depth) + 40,
              sizeBytes: await _dirSize(entity),
            ),
          );
          continue;
        }
        await _walk(entity, folderName, depth + 1, maxDepth, out);
        continue;
      }

      if (entity is! File) continue;
      final candidate = await _evaluateFile(entity, name, depth, folderName);
      if (candidate != null) out.add(candidate);
    }
  }

  static Future<ExecutableCandidate?> _evaluateFile(
    File file,
    String name,
    int depth,
    String folderName,
  ) async {
    final lower = name.toLowerCase();
    int base;

    if (Platform.isWindows) {
      if (!lower.endsWith('.exe') && !lower.endsWith('.bat')) return null;
      base = lower.endsWith('.exe') ? 30 : 10;
    } else if (Platform.isMacOS) {
      if (lower.endsWith('.sh') || lower.endsWith('.command')) {
        base = 20;
      } else if (await _isExecutable(file)) {
        base = 15;
      } else {
        return null;
      }
    } else {
      if (lower.endsWith('.sh') ||
          lower.endsWith('.x86_64') ||
          lower.endsWith('.appimage')) {
        base = 25;
      } else if (await _isExecutable(file)) {
        base = 15;
      } else {
        return null;
      }
    }

    int size = 0;
    try {
      size = await file.length();
    } on FileSystemException {
      return null;
    }

    return ExecutableCandidate(
      path: file.path,
      name: name,
      score:
          base +
          _score(name, depth) +
          _matchesFolder(name, folderName) +
          (size > 5 * 1024 * 1024 ? 10 : 0),
      sizeBytes: size,
    );
  }

  /// Насколько имя файла похоже на имя папки игры.
  ///
  /// Самый сильный признак из имеющихся, и до сих пор не использованный:
  /// `Hollow Knight/hollow_knight.exe` — очевидный ответ, а рядом лежащий
  /// `crashpad.exe` получал столько же очков. Мерку берём ту же, что и для
  /// имён раздач: игры называют свои файлы по-разному, но узнаваемо.
  static int _matchesFolder(String name, String folderName) {
    if (folderName.isEmpty) return 0;
    final file = ReleaseName.clean(p.basenameWithoutExtension(name));
    final folder = ReleaseName.clean(folderName);
    if (file.isEmpty || folder.isEmpty) return 0;
    final similarity = ReleaseName.similarity(file, folder);
    if (similarity >= 0.99) return 45;
    if (similarity >= 0.5) return 25;
    return 0;
  }

  static int _score(String name, int depth) {
    final lower = name.toLowerCase();
    var score = -depth * 5;
    for (final junk in _junkMarkers) {
      if (lower.contains(junk)) score -= 60;
    }
    if (lower.contains('launcher')) score += 5;
    if (lower.contains('game') || lower.contains('start')) score += 5;
    return score;
  }

  static Future<bool> _isExecutable(File file) async {
    try {
      final stat = await file.stat();
      // 0x49 = --x--x--x
      return stat.mode & 0x49 != 0 && stat.size > 0;
    } on FileSystemException {
      return false;
    }
  }

  static Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
          if (total > 2 * 1024 * 1024 * 1024) break;
        }
      }
    } on FileSystemException {
      return total;
    }
    return total;
  }
}
