part of 'save_manager.dart';

/// Проверка пакета, подготовка новых целей и откат файловой транзакции.
/// Ни один исходный путь не изменяется до полной подготовки всех целей.
extension _RestoreTransaction on SaveManager {
  _RestorePlan _buildRestorePlan(
    Archive archive,
    Map<String, _RestoreTarget> targets,
  ) {
    final entries = <_RestoreEntry>[];
    final destinations = <String>{};
    final fileRuleCounts = <String, int>{};
    var bytes = 0;

    for (final file in archive.files) {
      if (file.isSymbolicLink) {
        throw SaveException(_l.savePathEscapes(file.name));
      }
      if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;
      final parsed = SaveManager._parseEntryName(file.name);
      if (parsed == null) continue;
      final target = targets[parsed.ruleId];
      if (target == null) continue;

      final relative = parsed.relativePath.replaceAll(r'\', '/');
      final parts = relative.split('/');
      if (relative.isEmpty ||
          p.posix.isAbsolute(relative) ||
          p.windows.isAbsolute(relative) ||
          (Platform.isWindows && relative.contains(':')) ||
          parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
        throw SaveException(_l.savePathEscapes(file.name));
      }

      late final String destination;
      if (target.isFile) {
        final count = (fileRuleCounts[parsed.ruleId] ?? 0) + 1;
        fileRuleCounts[parsed.ruleId] = count;
        if (count > 1 || parts.length != 1) {
          throw SaveException(_l.savePathEscapes(file.name));
        }
        destination = target.path;
      } else {
        destination = p.normalize(p.joinAll([target.path, ...parts]));
        if (!p.isWithin(target.path, destination)) {
          throw SaveException(_l.savePathEscapes(file.name));
        }
      }

      if (!destinations.add(destination)) {
        throw SaveException(_l.saveArchiveReadFailed(file.name));
      }
      bytes += file.size;
      if (bytes > SaveManager._maxSnapshotBytes) {
        throw SaveException(_l.saveTooLarge(formatBytes(bytes)));
      }
      entries.add(
        _RestoreEntry(
          archiveFile: file,
          target: target,
          destination: destination,
        ),
      );
    }
    final usedTargets = entries.map((entry) => entry.target).toSet().toList();
    for (var i = 0; i < usedTargets.length; i++) {
      for (var j = i + 1; j < usedTargets.length; j++) {
        final a = usedTargets[i].path;
        final b = usedTargets[j].path;
        if (p.equals(a, b) || p.isWithin(a, b) || p.isWithin(b, a)) {
          throw SaveException(_l.savePathEscapes('$a / $b'));
        }
      }
    }
    if (entries.isEmpty) throw SaveNothingFoundException(_l.saveNothingFound);
    return _RestorePlan(entries: entries, bytes: bytes);
  }

  Future<void> _commitRestore(
    _RestorePlan plan, {
    required bool wipeTarget,
  }) async {
    final prepared = <_PreparedTarget>[];
    final committed = <_CommittedTarget>[];
    try {
      for (final group in plan.byTarget.entries) {
        final target = group.key;
        final token = SaveManager._uuid.v4();
        final candidatePath = p.join(
          p.dirname(target.path),
          '.${p.basename(target.path)}.evaporate-new-$token',
        );
        prepared.add(_PreparedTarget(target: target, path: candidatePath));
        if ((await FileSystemEntity.type(target.path, followLinks: false)) ==
            FileSystemEntityType.link) {
          throw SaveException(_l.savePathEscapes(target.path));
        }
        await Directory(p.dirname(target.path)).create(recursive: true);

        if (target.isFile) {
          if (await Directory(target.path).exists()) {
            throw FileSystemException('Expected a file', target.path);
          }
          final entry = group.value.single;
          await _writeArchiveFile(entry.archiveFile, candidatePath);
        } else {
          if (await File(target.path).exists()) {
            throw FileSystemException('Expected a directory', target.path);
          }
          final candidate = Directory(candidatePath);
          await candidate.create(recursive: true);
          if (!wipeTarget && await Directory(target.path).exists()) {
            await _copyDirectory(Directory(target.path), candidate);
          }
          for (final entry in group.value) {
            final relative = p.relative(entry.destination, from: target.path);
            await _writeArchiveFile(
              entry.archiveFile,
              p.join(candidate.path, relative),
            );
          }
        }
      }

      for (final item in prepared) {
        final backupPath =
            '${item.target.path}.evaporate-old-${SaveManager._uuid.v4()}';
        final existed = await _entityExists(item.target);
        if (existed) {
          await _renameEntity(item.target, item.target.path, backupPath);
        }
        try {
          await _renameEntity(item.target, item.path, item.target.path);
        } on Object {
          if (existed) {
            await _renameEntity(item.target, backupPath, item.target.path);
          }
          rethrow;
        }
        committed.add(
          _CommittedTarget(
            target: item.target,
            backupPath: existed ? backupPath : null,
          ),
        );
      }
    } on Object catch (error) {
      for (final item in committed.reversed) {
        if (await _entityExists(item.target)) {
          await _deleteEntity(item.target, item.target.path);
        }
        if (item.backupPath != null) {
          await _renameEntity(item.target, item.backupPath!, item.target.path);
        }
      }
      throw error is SaveException
          ? error
          : SaveException(_l.saveArchiveReadFailed('$error'));
    } finally {
      for (final item in prepared) {
        try {
          await _deleteEntity(item.target, item.path);
        } on FileSystemException {
          // Подготовленный файл не является единственной копией сейва.
          // Ошибка его уборки не должна запускать откат завершённой операции.
        }
      }
    }
    // После успешной замены всех целей откатываться уже не нужно.
    // Ошибка удаления старой копии не должна удалить новые сохранения.
    for (final item in committed) {
      if (item.backupPath == null) continue;
      try {
        await _deleteEntity(item.target, item.backupPath!);
      } on FileSystemException {
        // Оставляем старую копию рядом с целью: это безопаснее её потери.
      }
    }
  }

  Future<void> _writeArchiveFile(ArchiveFile file, String path) async {
    final outFile = File(path);
    await outFile.parent.create(recursive: true);
    final output = OutputFileStream(path);
    try {
      file.writeContent(output);
    } finally {
      await output.close();
    }
    var crc = 0;
    var size = 0;
    await for (final chunk in outFile.openRead()) {
      size += chunk.length;
      crc = getCrc32(chunk, crc);
    }
    if (size != file.size || (file.crc32 != null && crc != file.crc32)) {
      throw SaveException(_l.saveArchiveReadFailed(file.name));
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      final destination = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await File(destination).parent.create(recursive: true);
        await entity.copy(destination);
      } else if (entity is Link) {
        // Не теряем ссылку при слиянии и не пишем по ней вне цели.
        throw SaveException(_l.savePathEscapes(entity.path));
      }
    }
  }

  Future<bool> _entityExists(_RestoreTarget target) => target.isFile
      ? File(target.path).exists()
      : Directory(target.path).exists();

  Future<void> _renameEntity(_RestoreTarget target, String from, String to) =>
      _renameForRestore(target.isFile ? File(from) : Directory(from), to);

  Future<void> _deleteEntity(_RestoreTarget target, String path) async {
    if (target.isFile) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } else {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}

class _RestoreTarget {
  const _RestoreTarget({required this.path, required this.isFile});

  final String path;
  final bool isFile;

  @override
  bool operator ==(Object other) =>
      other is _RestoreTarget && other.path == path && other.isFile == isFile;

  @override
  int get hashCode => Object.hash(path, isFile);
}

class _RestoreEntry {
  const _RestoreEntry({
    required this.archiveFile,
    required this.target,
    required this.destination,
  });

  final ArchiveFile archiveFile;
  final _RestoreTarget target;
  final String destination;
}

class _RestorePlan {
  const _RestorePlan({required this.entries, required this.bytes});

  final List<_RestoreEntry> entries;
  final int bytes;

  Map<_RestoreTarget, List<_RestoreEntry>> get byTarget {
    final result = <_RestoreTarget, List<_RestoreEntry>>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.target, () => []).add(entry);
    }
    return result;
  }
}

class _PreparedTarget {
  const _PreparedTarget({required this.target, required this.path});

  final _RestoreTarget target;
  final String path;
}

class _CommittedTarget {
  const _CommittedTarget({required this.target, required this.backupPath});

  final _RestoreTarget target;
  final String? backupPath;
}
