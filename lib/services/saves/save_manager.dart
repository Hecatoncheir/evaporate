import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';

class SaveException implements Exception {
  SaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Что получилось при восстановлении: UI показывает это пользователю,
/// а не молча делает вид, что всё прошло гладко.
class RestoreReport {
  const RestoreReport({
    required this.filesWritten,
    required this.bytesWritten,
    required this.targets,
    required this.unresolved,
    this.backup,
  });

  final int filesWritten;
  final int bytesWritten;

  /// label правила -> куда легли файлы на этом устройстве.
  final Map<String, String> targets;

  /// Правила из пакета, которым не нашлось соответствия на этой платформе.
  final List<String> unresolved;
  final SaveSnapshot? backup;

  bool get isComplete => unresolved.isEmpty;
}

/// Метаданные пакета `.evsave`, прочитанные без полной распаковки.
class SavePackageInfo {
  const SavePackageInfo({
    required this.path,
    required this.snapshot,
    required this.isCompatible,
  });

  final String path;
  final SaveSnapshot snapshot;

  /// Хотя бы одно правило можно разложить на текущей платформе.
  final bool isCompatible;
}

/// Упаковка, распаковка и перенос сохранений между устройствами.
///
/// Формат `.evsave` — обычный zip:
///   `manifest.json`     — метаданные и правила путей;
///   `data/<ruleId>/...` — файлы сейвов, разложенные по правилам.
class SaveManager {
  SaveManager({AppPaths? paths}) : _paths = paths ?? AppPaths.instance;

  final AppPaths _paths;
  static const _uuid = Uuid();

  /// Системный мусор не должен попадать в сейвы.
  static const _skipNames = {'.DS_Store', 'Thumbs.db', 'desktop.ini'};

  /// Предохранитель от «указал папку игры целиком вместо папки сейвов».
  static const _maxSnapshotBytes = 4 * 1024 * 1024 * 1024;

  Future<SaveSnapshot> createSnapshot(
    Game game, {
    SnapshotOrigin origin = SnapshotOrigin.manual,
    String? note,
  }) async {
    final rules = game.saveProfile.rulesForCurrentPlatform;
    if (rules.isEmpty) {
      throw SaveException(
        'Для «${game.title}» не заданы папки сохранений на ${platformLabel(currentPlatformKey())}.',
      );
    }

    // Сначала обходим файлы, чтобы манифест содержал честные размеры.
    final entries = <_PendingEntry>[];
    final usedRules = <SavePathRule>[];
    var totalBytes = 0;

    for (final rule in rules) {
      final resolved = rule.resolve();
      final collected = await _collect(rule, resolved);
      if (collected.isEmpty) continue;
      usedRules.add(rule);
      entries.addAll(collected);
      for (final entry in collected) {
        totalBytes += entry.size;
      }
    }

    if (entries.isEmpty) {
      throw SaveException(
        'Ничего не найдено по заданным путям. Проверьте настройки сохранений — '
        'возможно, игра ещё не создала папку.',
      );
    }
    if (totalBytes > _maxSnapshotBytes) {
      throw SaveException(
        'Суммарный размер ${formatBytes(totalBytes)} слишком велик для снимка '
        'сохранений. Похоже, в правилах указана папка игры, а не сейвов.',
      );
    }

    final id = _uuid.v4();
    final dir = Directory(_paths.snapshotDirFor(game.id));
    await dir.create(recursive: true);
    final stamp = DateTime.now();
    final archivePath = p.join(
      dir.path,
      '${_timestampSlug(stamp)}-${id.substring(0, 8)}${SaveSnapshot.fileExtension}',
    );

    final snapshot = SaveSnapshot(
      id: id,
      gameId: game.id,
      gameTitle: game.title,
      createdAt: stamp,
      deviceName: currentDeviceName(),
      platform: currentPlatformKey(),
      sizeBytes: totalBytes,
      archivePath: archivePath,
      rules: usedRules,
      playtime: game.playtime,
      note: note,
      fileCount: entries.length,
      origin: origin,
    );

    final encoder = ZipFileEncoder();
    encoder.create(archivePath);
    try {
      encoder.addArchiveFile(
        ArchiveFile.string(
          SaveSnapshot.manifestEntry,
          const JsonEncoder.withIndent('  ').convert(snapshot.toManifest()),
        ),
      );
      for (final entry in entries) {
        await encoder.addFile(File(entry.sourcePath), entry.archiveName);
      }
    } finally {
      await encoder.close();
    }

    return snapshot;
  }

  Future<List<_PendingEntry>> _collect(
    SavePathRule rule,
    String resolved,
  ) async {
    final entries = <_PendingEntry>[];
    final prefix = '${SaveSnapshot.dataPrefix}/${rule.id}';

    final file = File(resolved);
    if (await file.exists()) {
      entries.add(
        _PendingEntry(
          sourcePath: resolved,
          archiveName: '$prefix/${p.basename(resolved)}',
          size: await file.length(),
        ),
      );
      return entries;
    }

    final directory = Directory(resolved);
    if (!await directory.exists()) return entries;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (_skipNames.contains(name)) continue;
      final relative = p
          .relative(entity.path, from: directory.path)
          .replaceAll(r'\', '/');
      entries.add(
        _PendingEntry(
          sourcePath: entity.path,
          archiveName: '$prefix/$relative',
          size: await entity.length(),
        ),
      );
    }
    return entries;
  }

  /// Разворачивает снапшот на текущем устройстве.
  ///
  /// Сопоставление правил идёт сначала по id, затем по метке — так сейв,
  /// снятый на Windows, ложится в macOS-путь той же игры.
  Future<RestoreReport> restoreSnapshot({
    required Game game,
    required SaveSnapshot snapshot,
    bool backupCurrent = true,
    bool wipeTarget = false,
  }) async {
    final archive = await _openArchive(snapshot.archivePath);
    try {
      return await _restoreFrom(
        archive: archive,
        game: game,
        snapshot: snapshot,
        backupCurrent: backupCurrent,
        wipeTarget: wipeTarget,
      );
    } finally {
      // Освобождаем файловые хендлы, которые держит распакованный архив.
      await archive.clear();
    }
  }

  Future<RestoreReport> _restoreFrom({
    required Archive archive,
    required Game game,
    required SaveSnapshot snapshot,
    required bool backupCurrent,
    required bool wipeTarget,
  }) async {
    final manifest = _readManifest(archive) ?? snapshot.toManifest();
    final manifestRules = (manifest['rules'] as List<dynamic>? ?? [])
        .map((e) => SavePathRule.fromJson(e as Map<String, dynamic>))
        .toList();

    final targets = <String, String>{};
    final targetByRuleId = <String, String>{};
    final unresolved = <String>[];

    for (final rule in manifestRules) {
      final local = _matchLocalRule(game, rule);
      if (local == null) {
        unresolved.add(rule.label);
        continue;
      }
      final resolved = local.resolve();
      targetByRuleId[rule.id] = resolved;
      targets[local.label] = resolved;
    }

    if (targetByRuleId.isEmpty) {
      throw SaveException(
        'Не удалось сопоставить ни одного пути сохранений с этим устройством. '
        'Задайте папку сохранений в карточке игры и повторите.',
      );
    }

    SaveSnapshot? backup;
    if (backupCurrent) {
      try {
        backup = await createSnapshot(
          game,
          origin: SnapshotOrigin.preRestore,
          note:
              'Автобэкап перед откатом на ${formatDateTime(snapshot.createdAt)}',
        );
      } on SaveException {
        // Бэкапить нечего (первый запуск на этом устройстве) — это нормально.
      }
    }

    if (wipeTarget) {
      for (final dirPath in targetByRuleId.values.toSet()) {
        final dir = Directory(dirPath);
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    }

    var filesWritten = 0;
    var bytesWritten = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == SaveSnapshot.manifestEntry) continue;
      final parsed = _parseEntryName(file.name);
      if (parsed == null) continue;
      final targetDir = targetByRuleId[parsed.ruleId];
      if (targetDir == null) continue;

      final destination = p.normalize(p.join(targetDir, parsed.relativePath));
      // Защита от zip-slip: пакет мог приехать откуда угодно.
      if (!p.isWithin(targetDir, destination)) {
        throw SaveException(
          'Пакет содержит путь за пределами папки сохранений: ${file.name}',
        );
      }

      final outFile = File(destination);
      await outFile.parent.create(recursive: true);
      final output = OutputFileStream(destination);
      try {
        file.writeContent(output);
      } finally {
        await output.close();
      }
      filesWritten++;
      bytesWritten += file.size;
    }

    return RestoreReport(
      filesWritten: filesWritten,
      bytesWritten: bytesWritten,
      targets: targets,
      unresolved: unresolved,
      backup: backup,
    );
  }

  /// id -> метка -> «правило само подходит этой платформе».
  SavePathRule? _matchLocalRule(Game game, SavePathRule incoming) {
    final local = game.saveProfile.rulesForCurrentPlatform;
    for (final rule in local) {
      if (rule.id == incoming.id) return rule;
    }
    final wanted = incoming.label.trim().toLowerCase();
    for (final rule in local) {
      if (rule.label.trim().toLowerCase() == wanted) return rule;
    }
    if (incoming.appliesToCurrentPlatform()) return incoming;
    return null;
  }

  /// Копирует пакет наружу — на флешку, в облачную папку, куда угодно.
  Future<File> exportSnapshot(
    SaveSnapshot snapshot,
    String destinationPath,
  ) async {
    final source = File(snapshot.archivePath);
    if (!await source.exists()) {
      throw SaveException('Архив снимка не найден: ${snapshot.archivePath}');
    }
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    return source.copy(destination.path);
  }

  /// Читает манифест пакета, ничего не распаковывая.
  Future<SavePackageInfo> inspectPackage(String path) async {
    final archive = await _openArchive(path);
    final manifest = _readManifest(archive);
    await archive.clear();
    if (manifest == null) {
      throw SaveException('Это не пакет сохранений Evaporate.');
    }
    if (manifest['format'] != SaveSnapshot.manifestFormat) {
      throw SaveException(
        'Неподдерживаемая версия пакета: ${manifest['format']}',
      );
    }

    final rules = (manifest['rules'] as List<dynamic>? ?? [])
        .map((e) => SavePathRule.fromJson(e as Map<String, dynamic>))
        .toList();

    final snapshot = SaveSnapshot(
      id: manifest['id'] as String? ?? _uuid.v4(),
      gameId: manifest['gameId'] as String? ?? '',
      gameTitle: manifest['gameTitle'] as String? ?? 'Без названия',
      createdAt:
          DateTime.tryParse(manifest['createdAt'] as String? ?? '') ??
          DateTime.now(),
      deviceName: manifest['deviceName'] as String? ?? 'неизвестно',
      platform: manifest['platform'] as String? ?? '',
      sizeBytes: manifest['sizeBytes'] as int? ?? 0,
      archivePath: path,
      rules: rules,
      playtime: Duration(seconds: manifest['playtimeSeconds'] as int? ?? 0),
      note: manifest['note'] as String?,
      fileCount: manifest['fileCount'] as int? ?? 0,
      origin: SnapshotOrigin.imported,
    );

    final compatible = rules.any((r) => r.appliesToCurrentPlatform());
    return SavePackageInfo(
      path: path,
      snapshot: snapshot,
      isCompatible: compatible,
    );
  }

  /// Забирает пакет в хранилище приложения и привязывает к игре.
  Future<SaveSnapshot> importPackage(String path, {required Game game}) async {
    final info = await inspectPackage(path);
    final dir = Directory(_paths.snapshotDirFor(game.id));
    await dir.create(recursive: true);
    final target = p.join(
      dir.path,
      '${_timestampSlug(info.snapshot.createdAt)}-imported-'
      '${info.snapshot.id.substring(0, info.snapshot.id.length.clamp(0, 8))}'
      '${SaveSnapshot.fileExtension}',
    );
    await File(path).copy(target);

    return SaveSnapshot(
      id: _uuid.v4(),
      gameId: game.id,
      gameTitle: info.snapshot.gameTitle,
      createdAt: info.snapshot.createdAt,
      deviceName: info.snapshot.deviceName,
      platform: info.snapshot.platform,
      sizeBytes: info.snapshot.sizeBytes,
      archivePath: target,
      rules: info.snapshot.rules,
      playtime: info.snapshot.playtime,
      note: info.snapshot.note,
      fileCount: info.snapshot.fileCount,
      origin: SnapshotOrigin.imported,
    );
  }

  Future<void> deleteSnapshot(SaveSnapshot snapshot) async {
    final file = File(snapshot.archivePath);
    if (await file.exists()) await file.delete();
  }

  /// Сканирует папку синхронизации (Dropbox, Syncthing, iCloud) на пакеты
  /// с других устройств.
  Future<List<SavePackageInfo>> scanSyncFolder(String folder) async {
    final dir = Directory(folder);
    if (!await dir.exists()) return const [];
    final result = <SavePackageInfo>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith(SaveSnapshot.fileExtension)) continue;
      try {
        result.add(await inspectPackage(entity.path));
      } on Object {
        // Битый или чужой файл просто пропускаем.
      }
    }
    result.sort((a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt));
    return result;
  }

  Future<Archive> _openArchive(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw SaveException('Файл не найден: $path');
    }
    try {
      return ZipDecoder().decodeStream(InputFileStream(path));
    } on Object catch (error) {
      throw SaveException('Не удалось прочитать архив: $error');
    }
  }

  Map<String, dynamic>? _readManifest(Archive archive) {
    for (final file in archive.files) {
      if (file.name != SaveSnapshot.manifestEntry) continue;
      try {
        final decoded = jsonDecode(utf8.decode(file.content));
        if (decoded is Map<String, dynamic>) return decoded;
      } on Object {
        return null;
      }
    }
    return null;
  }

  static _EntryName? _parseEntryName(String name) {
    final normalized = name.replaceAll(r'\', '/');
    final parts = normalized.split('/');
    if (parts.length < 3) return null;
    if (parts.first != SaveSnapshot.dataPrefix) return null;
    return _EntryName(parts[1], parts.sublist(2).join('/'));
  }

  static String _timestampSlug(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}'
        '-${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _PendingEntry {
  const _PendingEntry({
    required this.sourcePath,
    required this.archiveName,
    required this.size,
  });

  final String sourcePath;
  final String archiveName;
  final int size;
}

class _EntryName {
  const _EntryName(this.ruleId, this.relativePath);

  final String ruleId;
  final String relativePath;
}
