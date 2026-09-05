import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../core/format.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import 'snapshot_store.dart';

part 'restore_transaction.dart';

class SaveException implements Exception {
  SaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SaveNothingFoundException extends SaveException {
  SaveNothingFoundException(super.message);
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
  SaveManager({
    AppPaths? paths,
    L Function()? localizations,
    Future<FileSystemEntity> Function(FileSystemEntity, String)?
    renameForRestore,
    Future<void> Function(ZipFileEncoder, File, String)? addToArchive,
  }) : _paths = paths ?? AppPaths.instance,
       _renameForRestore = renameForRestore ?? _rename,
       _addToArchive = addToArchive ?? _addFile,
       _localizations = localizations ?? _defaultLocalizations,
       store = SnapshotStore(root: (paths ?? AppPaths.instance).blobsDir);

  /// Хранилище файлов снимков по содержимому.
  ///
  /// Открыто наружу: уборку неиспользуемого запускает библиотека — только
  /// она знает полный список живых снимков.
  final SnapshotStore store;

  final AppPaths _paths;
  // Подмена файловой операции позволяет проверять откат при сбое на
  // второй цели без ненадёжных тестов прав доступа на разных ОС.
  final Future<FileSystemEntity> Function(FileSystemEntity, String)
  _renameForRestore;
  static Future<FileSystemEntity> _rename(FileSystemEntity source, String to) =>
      source.rename(to);

  // По той же причине подменяется и запись файла в архив: сбой на середине
  // снимка иначе пришлось бы вызывать правами доступа, а они на трёх
  // системах ведут себя по-разному.
  final Future<void> Function(ZipFileEncoder, File, String) _addToArchive;
  static Future<void> _addFile(
    ZipFileEncoder encoder,
    File file,
    String name,
  ) => encoder.addFile(file, name);

  /// Откуда брать переводы: сообщения об ошибках доходят до пользователя
  /// уведомлениями, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();
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
        _l.saveNoPathsForPlatform(
          game.title,
          platformLabel(currentPlatformKey()),
        ),
      );
    }

    // Сначала обходим файлы, чтобы манифест содержал честные размеры.
    final entries = <_PendingEntry>[];
    final usedRules = <SavePathRule>[];
    var totalBytes = 0;

    for (final rule in rules) {
      final resolved = rule.resolve(gameDir: game.installDir);
      // Игра не установлена, а правило указывает внутрь её папки — брать
      // нечего, и это не ошибка.
      if (resolved == null) continue;
      final isFile = await File(resolved).exists();
      final collected = await _collect(rule, resolved);
      if (collected.isEmpty) continue;
      usedRules.add(
        rule.copyWith(
          kind: isFile ? SavePathKind.file : SavePathKind.directory,
        ),
      );
      entries.addAll(collected);
      for (final entry in collected) {
        totalBytes += entry.size;
      }
    }

    if (entries.isEmpty) {
      throw SaveNothingFoundException(_l.saveNothingFound);
    }
    if (totalBytes > _maxSnapshotBytes) {
      throw SaveException(_l.saveTooLarge(formatBytes(totalBytes)));
    }

    final id = _uuid.v4();
    final stamp = DateTime.now();

    // Своего архива у снимка нет: файлы уходят в хранилище по содержимому,
    // а пакет собирается из ссылок, когда его просят унести наружу.
    // Одинаковые файлы соседних снимков при этом лежат на диске один раз.
    final blobs = <SnapshotBlob>[];
    for (final entry in entries) {
      blobs.add(await store.put(entry.archiveName, File(entry.sourcePath)));
    }

    return SaveSnapshot(
      id: id,
      gameId: game.id,
      gameTitle: game.title,
      createdAt: stamp,
      deviceName: currentDeviceName(),
      platform: currentPlatformKey(),
      sizeBytes: totalBytes,
      archivePath: '',
      rules: usedRules,
      playtime: game.playtime,
      note: note,
      fileCount: entries.length,
      origin: origin,
      blobs: blobs,
    );
  }

  /// Собирает настоящий `.evsave` из ссылок на содержимое.
  ///
  /// Пакет обязан оставаться самодостаточным zip: его уносят на другую
  /// машину и читают чужие сборки, которые про здешнее хранилище ничего не
  /// знают и знать не должны.
  Future<File> _materialize(SaveSnapshot snapshot, String destination) async {
    final target = File(destination);
    await target.parent.create(recursive: true);

    final encoder = ZipFileEncoder();
    encoder.create(destination);
    var complete = false;
    try {
      encoder.addArchiveFile(
        ArchiveFile.string(
          SaveSnapshot.manifestEntry,
          const JsonEncoder.withIndent('  ').convert(snapshot.toManifest()),
        ),
      );
      // Содержимое в хранилище лежит сжатым, а zip-упаковщику нужен
      // обычный файл — распаковываем по одному, а не всё разом: снимок
      // может весить гигабайты, и держать их в памяти нечем.
      for (final blob in snapshot.blobs) {
        if (!await store.fileFor(blob.hash).exists()) {
          throw SaveException(_l.saveArchiveMissing(blob.name));
        }
        final staged = File('$destination.${blob.hash}.part');
        try {
          await store.extractTo(blob.hash, staged.path);
          await _addToArchive(encoder, staged, blob.name);
        } finally {
          if (await staged.exists()) await staged.delete();
        }
      }
      complete = true;
    } finally {
      await encoder.close();
      if (!complete) {
        try {
          if (await target.exists()) await target.delete();
        } on FileSystemException {
          // Уборка не удалась — исходную ошибку подменять этим не станем.
        }
      }
    }
    return target;
  }

  /// Когда сохранения игры в последний раз менялись на этом устройстве.
  ///
  /// Нужно, чтобы не затереть свежий прогресс пакетом с другого устройства:
  /// сравнивать больше нечего — общего журнала у устройств нет, есть только
  /// время изменения файлов и время снятия пакета.
  ///
  /// `null` означает, что сохранений нет вовсе, — затирать нечего.
  Future<DateTime?> lastLocalChange(Game game) async {
    DateTime? newest;

    for (final rule in game.saveProfile.rulesForCurrentPlatform) {
      final resolved = rule.resolve(gameDir: game.installDir);
      if (resolved == null) continue;

      final file = File(resolved);
      if (await file.exists()) {
        final modified = (await file.stat()).modified;
        if (newest == null || modified.isAfter(newest)) newest = modified;
        continue;
      }

      final directory = Directory(resolved);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (_skipNames.contains(p.basename(entity.path))) continue;
        final modified = (await entity.stat()).modified;
        if (newest == null || modified.isAfter(newest)) newest = modified;
      }
    }
    return newest;
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
    // Снимок из хранилища по содержимому своего архива не имеет, поэтому
    // собираем временный. Разбирать его дальше будет тот же самый код:
    // раскладка файлов по целям — самое опасное место приложения, и
    // заводить ей вторую реализацию ради экономии временного файла значило
    // бы удвоить то, что обязано быть одним.
    final source = snapshot.isDeduplicated
        ? await _materialize(snapshot, _temporaryPackagePath(snapshot))
        : null;
    final path = source?.path ?? snapshot.archivePath;

    final archive = await _openArchive(path);
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
      if (source != null && await source.exists()) await source.delete();
    }
  }

  /// Куда собрать пакет, который нужен только на время операции.
  String _temporaryPackagePath(SaveSnapshot snapshot) => p.join(
    _paths.snapshotDirFor(snapshot.gameId),
    '.${snapshot.id}-${DateTime.now().microsecondsSinceEpoch}'
    '${SaveSnapshot.fileExtension}',
  );

  Future<RestoreReport> _restoreFrom({
    required Archive archive,
    required Game game,
    required SaveSnapshot snapshot,
    required bool backupCurrent,
    required bool wipeTarget,
  }) async {
    final manifest = _readManifest(archive);
    if (manifest == null) {
      throw SaveException(_l.saveNotEvaporatePackage);
    }
    if (!SaveSnapshot.readableFormats.contains(manifest['format'])) {
      throw SaveException(_l.saveUnsupportedVersion('${manifest['format']}'));
    }

    final manifestRules = _readRules(manifest);

    final targets = <String, String>{};
    final targetByRuleId = <String, _RestoreTarget>{};
    final unresolved = <String>[];

    for (final rule in manifestRules) {
      final local = _matchLocalRule(game, rule);
      if (local == null) {
        unresolved.add(rule.label);
        continue;
      }
      final resolved = local.resolve(gameDir: game.installDir);
      if (resolved == null) {
        unresolved.add(rule.label);
        continue;
      }
      final isFile =
          local.kind == SavePathKind.file ||
          rule.kind == SavePathKind.file ||
          await File(resolved).exists();
      targetByRuleId[rule.id] = _RestoreTarget(
        path: p.normalize(p.absolute(resolved)),
        isFile: isFile,
      );
      targets[local.label] = resolved;
    }

    if (targetByRuleId.isEmpty) {
      throw SaveException(_l.saveNoTargets);
    }

    final plan = _buildRestorePlan(archive, targetByRuleId);

    SaveSnapshot? backup;
    if (backupCurrent) {
      try {
        backup = await createSnapshot(
          game,
          origin: SnapshotOrigin.preRestore,
          note: _l.saveAutoBackupNote(formatDateTime(snapshot.createdAt)),
        );
      } on SaveNothingFoundException {
        // Первый запуск на этом устройстве: резервировать пока нечего.
      }
    }

    await _commitRestore(plan, wipeTarget: wipeTarget);

    return RestoreReport(
      filesWritten: plan.entries.length,
      bytesWritten: plan.bytes,
      targets: targets,
      unresolved: unresolved,
      backup: backup,
    );
  }

  /// Путь из внешнего манифеста никогда не становится локальной целью.
  /// Сопоставляем только с явно настроенными у игры путями: id -> метка.
  SavePathRule? _matchLocalRule(Game game, SavePathRule incoming) {
    final local = game.saveProfile.rulesForCurrentPlatform;
    for (final rule in local) {
      if (rule.id == incoming.id) return rule;
    }
    final wanted = incoming.label.trim().toLowerCase();
    final matches = local
        .where((rule) => rule.label.trim().toLowerCase() == wanted)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  List<SavePathRule> _readRules(Map<String, dynamic> manifest) {
    try {
      final rules = (manifest['rules'] as List<dynamic>? ?? [])
          .map((e) => SavePathRule.fromJson(e as Map<String, dynamic>))
          .toList();
      final ids = <String>{};
      for (final rule in rules) {
        if (rule.id.isEmpty ||
            rule.id.contains(RegExp(r'[/\\]')) ||
            !ids.add(rule.id)) {
          throw const FormatException('Invalid or duplicate rule ID');
        }
      }
      return rules;
    } on Object catch (error) {
      throw SaveException(_l.saveArchiveReadFailed('$error'));
    }
  }

  /// Копирует пакет наружу — на флешку, в облачную папку, куда угодно.
  Future<File> exportSnapshot(
    SaveSnapshot snapshot,
    String destinationPath,
  ) async {
    // Снимок из хранилища собирается сразу по назначению: лишней копии
    // здесь не нужно, а пакет всё равно пишется целиком.
    if (snapshot.isDeduplicated) {
      return _materialize(snapshot, destinationPath);
    }
    final source = File(snapshot.archivePath);
    if (!await source.exists()) {
      throw SaveException(_l.saveArchiveMissing(snapshot.archivePath));
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
      throw SaveException(_l.saveNotEvaporatePackage);
    }
    if (!SaveSnapshot.readableFormats.contains(manifest['format'])) {
      throw SaveException(_l.saveUnsupportedVersion('${manifest['format']}'));
    }

    final rules = _readRules(manifest);

    final snapshot = SaveSnapshot(
      id: manifest['id'] as String? ?? _uuid.v4(),
      gameId: manifest['gameId'] as String? ?? '',
      gameTitle: manifest['gameTitle'] as String? ?? _l.untitled,
      createdAt:
          DateTime.tryParse(manifest['createdAt'] as String? ?? '') ??
          DateTime.now(),
      deviceName: manifest['deviceName'] as String? ?? _l.saveUnknownDevice,
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
    final id = _uuid.v4();

    // Пакет разбираем в хранилище, а не кладём копией: чужой снимок часто
    // повторяет здешние почти целиком — привезли ту же игру с другой
    // машины, — и класть его отдельным архивом значит хранить одно и то же
    // дважды. Содержимое переливаем через временный файл, а не читаем в
    // память: пакет может весить гигабайты.
    final dir = Directory(_paths.snapshotDirFor(game.id));
    await dir.create(recursive: true);
    final blobs = <SnapshotBlob>[];

    final archive = await _openArchive(path);
    try {
      for (final file in archive.files) {
        if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;
        if (_parseEntryName(file.name) == null) continue;
        final tmp = File(
          p.join(dir.path, '.import-${DateTime.now().microsecondsSinceEpoch}'),
        );
        final output = OutputFileStream(tmp.path);
        try {
          file.writeContent(output);
        } finally {
          await output.close();
        }
        try {
          blobs.add(await store.put(file.name, tmp));
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
      }
    } finally {
      await archive.clear();
    }

    if (blobs.isEmpty) throw SaveNothingFoundException(_l.saveNothingFound);

    return SaveSnapshot(
      id: id,
      gameId: game.id,
      gameTitle: info.snapshot.gameTitle,
      createdAt: info.snapshot.createdAt,
      deviceName: info.snapshot.deviceName,
      platform: info.snapshot.platform,
      sizeBytes: info.snapshot.sizeBytes,
      archivePath: '',
      rules: info.snapshot.rules,
      playtime: info.snapshot.playtime,
      note: info.snapshot.note,
      fileCount: info.snapshot.fileCount,
      origin: SnapshotOrigin.imported,
      blobs: blobs,
    );
  }

  /// Убирает снимок.
  ///
  /// У снимка из хранилища удалять нечего: его содержимое может быть общим
  /// с соседними снимками, и разбирается с этим уборка — [SnapshotStore.collect],
  /// которой библиотека передаёт полный список живых ссылок.
  Future<void> deleteSnapshot(SaveSnapshot snapshot) async {
    if (snapshot.isDeduplicated) return;
    final file = File(snapshot.archivePath);
    if (await file.exists()) await file.delete();
  }

  /// Убирает содержимое, на которое больше никто не ссылается.
  ///
  /// Список живых ссылок собирает библиотека: только она видит все снимки
  /// всех игр разом, а хранилище — общее для них.
  Future<int> collectGarbage(Iterable<SaveSnapshot> alive) => store.collect({
    for (final snapshot in alive)
      for (final blob in snapshot.blobs) blob.hash,
  });

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
      throw SaveException(_l.fileNotFound(path));
    }
    try {
      return ZipDecoder().decodeStream(InputFileStream(path));
    } on Object catch (error) {
      throw SaveException(_l.saveArchiveReadFailed('$error'));
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
