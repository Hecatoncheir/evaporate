import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../system/app_log.dart';
import 'evsave_package.dart';
import 'restore_transaction.dart';
import 'rule_matcher.dart';
import 'save_collector.dart';
import 'save_exception.dart';
import 'snapshot_store.dart';

// Исключения уехали в свой файл — их бросают и пакет, и раскладка, — но
// зовут их отсюда по всему приложению.
export 'save_exception.dart';

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
    AppLog Function()? log,
    Future<FileSystemEntity> Function(FileSystemEntity, String)?
    renameForRestore,
    Future<void> Function(ZipFileEncoder, File, String)? addToArchive,
    this.maxSnapshotBytes = defaultMaxSnapshotBytes,
  }) : _paths = paths ?? AppPaths.instance,
       _renameForRestore = renameForRestore ?? _rename,
       _addToArchive = addToArchive ?? _addFile,
       _localizations = localizations ?? _defaultLocalizations,
       _log = log ?? _appLog,
       store = SnapshotStore(root: (paths ?? AppPaths.instance).blobsDir);

  /// Хранилище файлов снимков по содержимому.
  ///
  /// Открыто наружу: уборку неиспользуемого запускает библиотека — только
  /// она знает полный список живых снимков.
  final SnapshotStore store;

  final AppPaths _paths;

  /// Куда писать о том, что гасится молча: пропущенный пакет папки
  /// синхронизации, следы прерванной раскладки. Функцией, а не глобалом:
  /// глобал один на весь прогон, и тест, поставивший свой журнал,
  /// отбирает его у соседнего файла — тесты идут параллельно.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;

  /// Кто ходит по диску: отбор файлов для снимка и время последней правки.
  final _files = const SaveCollector();

  /// Кто решает, какому здешнему правилу отвечает правило из пакета.
  final _rules = const RuleMatcher();

  /// Кто разбирает сам файл пакета: архив, манифест, имена записей.
  late final _package = EvsavePackage(localizations: _localizations);

  /// Кто трогает чужие сохранения на месте: подготовка целей, замена и
  /// откат, если замена сорвалась.
  late final _restore = RestoreTransaction(
    localizations: _localizations,
    maxSnapshotBytes: maxSnapshotBytes,
    rename: _renameForRestore,
    log: _log,
  );
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

  /// Предохранитель от «указал папку игры целиком вместо папки сейвов».
  static const defaultMaxSnapshotBytes = 4 * 1024 * 1024 * 1024;

  /// Предел размера снимка; подменяется в тестах — пакет на четыре
  /// гигабайта там не собрать.
  final int maxSnapshotBytes;

  /// Снимает сейвы игры.
  ///
  /// Под [SnapshotStore.guard], как и всё, что кладёт содержимое в
  /// хранилище: пока снимок собирается, ссылаться на его файлы некому, и
  /// уборка от соседнего события унесла бы их у него из-под рук.
  Future<SaveSnapshot> createSnapshot(
    Game game, {
    SnapshotOrigin origin = SnapshotOrigin.manual,
    String? note,
  }) => store.guard(() async {
    await _restore.recoverInterrupted(game);
    return _createSnapshot(game, origin: origin, note: note);
  });

  Future<SaveSnapshot> _createSnapshot(
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
    final entries = <CollectedFile>[];
    final usedRules = <SavePathRule>[];
    var totalBytes = 0;

    for (final rule in rules) {
      final resolved = rule.resolve(gameDir: game.installDir);
      // Игра не установлена, а правило указывает внутрь её папки — брать
      // нечего, и это не ошибка.
      if (resolved == null) continue;
      final isFile = await File(resolved).exists();
      final collected = await _files.collect(rule, resolved);
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
    if (totalBytes > maxSnapshotBytes) {
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
      newest = SaveCollector.later(
        newest,
        await _files.newestChangeAt(resolved),
      );
    }
    return newest;
  }

  /// Разворачивает снапшот на текущем устройстве.
  ///
  /// Сопоставление правил идёт сначала по id, затем по метке — так сейв,
  /// снятый на Windows, ложится в macOS-путь той же игры.
  ///
  /// Отметка [SnapshotStore.guard] накрывает не только снятие резервной
  /// копии, но и заливку файлов: копия готова раньше, чем о ней узнает
  /// библиотека, и всё это время она — единственный путь назад.
  Future<RestoreReport> restoreSnapshot({
    required Game game,
    required SaveSnapshot snapshot,
    bool backupCurrent = true,
    bool wipeTarget = false,
  }) => store.guard(() async {
    await _restore.recoverInterrupted(game);
    return _restoreSnapshot(
      game: game,
      snapshot: snapshot,
      backupCurrent: backupCurrent,
      wipeTarget: wipeTarget,
    );
  });

  Future<RestoreReport> _restoreSnapshot({
    required Game game,
    required SaveSnapshot snapshot,
    required bool backupCurrent,
    required bool wipeTarget,
  }) async {
    // Снимок из хранилища раскладывают прямо оттуда. Прежде из него
    // собирался временный `.evsave`, и гигабайты сейвов сжимались, чтобы
    // тут же разжаться, — минуты работы и замершее окно ради файла,
    // который удаляли следующей строкой. Раскладка при этом осталась
    // одна: различается только то, откуда текут байты.
    if (snapshot.isDeduplicated) {
      return _restoreUsing(
        game: game,
        snapshot: snapshot,
        rules: snapshot.rules,
        sources: await _storedSources(snapshot),
        backupCurrent: backupCurrent,
        wipeTarget: wipeTarget,
      );
    }

    // Снимки, снятые до появления хранилища, лежат своими архивами.
    return _package.open(
      snapshot.archivePath,
      (archive) => _restoreUsing(
        game: game,
        snapshot: snapshot,
        rules: _package.rulesOf(
          _package.checkedManifest(_package.manifestOf(archive)),
        ),
        sources: _package.entriesOf(archive).toList(),
        backupCurrent: backupCurrent,
        wipeTarget: wipeTarget,
      ),
    );
  }

  /// Содержимое снимка из хранилища.
  ///
  /// Пропажу ловим здесь, до первой записи на диск: план строится целиком
  /// заранее, и половина разложенного снимка хуже, чем неразложенный.
  Future<List<RestoreSource>> _storedSources(SaveSnapshot snapshot) async {
    final sources = <RestoreSource>[];
    for (final blob in snapshot.blobs) {
      if (!await store.fileFor(blob.hash).exists()) {
        throw SaveException(_l.saveArchiveMissing(blob.name));
      }
      sources.add(
        StoredBlobSource(blob, store: store, localizations: _localizations),
      );
    }
    return sources;
  }

  Future<RestoreReport> _restoreUsing({
    required Game game,
    required SaveSnapshot snapshot,
    required List<SavePathRule> rules,
    required List<RestoreSource> sources,
    required bool backupCurrent,
    required bool wipeTarget,
  }) async {
    final resolved = await _resolveTargets(game, rules);
    if (resolved.byRuleId.isEmpty) {
      throw SaveException(_l.saveNoTargets);
    }

    final plan = _restore.buildPlan(sources, resolved.byRuleId);
    final backup = backupCurrent
        ? await _backupBeforeRestore(game, snapshot)
        : null;
    await _restore.commit(plan, wipeTarget: wipeTarget);

    return RestoreReport(
      filesWritten: plan.entries.length,
      bytesWritten: plan.bytes,
      targets: resolved.byLabel,
      unresolved: resolved.unresolved,
      backup: backup,
    );
  }

  /// Куда на этом устройстве ложится каждое правило пакета.
  ///
  /// Правило, которому места не нашлось, не отменяет остальные: пакет
  /// мог прийти с системы, где путей больше, — но названо оно будет в
  /// отчёте, иначе человек считал бы, что перенеслось всё.
  Future<_ResolvedTargets> _resolveTargets(
    Game game,
    List<SavePathRule> manifestRules,
  ) async {
    final byLabel = <String, String>{};
    final byRuleId = <String, RestoreTarget>{};
    final unresolved = <String>[];

    for (final rule in manifestRules) {
      final local = _rules.localFor(game, rule);
      final resolved = local?.resolve(gameDir: game.installDir);
      if (local == null || resolved == null) {
        unresolved.add(rule.label);
        continue;
      }
      // Файл это или папка, решают оба правила и сам диск: замена идёт
      // целиком, и ошибиться здесь значит снести папку вместо файла.
      final isFile =
          local.kind == SavePathKind.file ||
          rule.kind == SavePathKind.file ||
          await File(resolved).exists();
      byRuleId[rule.id] = RestoreTarget(
        path: p.normalize(p.absolute(resolved)),
        isFile: isFile,
      );
      byLabel[local.label] = resolved;
    }

    return _ResolvedTargets(
      byLabel: byLabel,
      byRuleId: byRuleId,
      unresolved: unresolved,
    );
  }

  /// Снимок того, что лежит сейчас, — до того, как его заменят.
  Future<SaveSnapshot?> _backupBeforeRestore(
    Game game,
    SaveSnapshot snapshot,
  ) async {
    try {
      return await createSnapshot(
        game,
        origin: SnapshotOrigin.preRestore,
        note: _l.saveAutoBackupNote(formatDateTime(snapshot.createdAt)),
      );
    } on SaveNothingFoundException {
      // Первый запуск на этом устройстве: резервировать пока нечего.
      return null;
    }
  }

  /// Куда лягут файлы снимка на этом устройстве: метка правила → путь.
  ///
  /// Нужно диалогу восстановления, который показывает это до нажатия:
  /// восстановление перезаписывает чужие сохранения, и место записи должно
  /// быть видно заранее. Отсюда же и требование к предпросмотру — он
  /// обязан идти **тем же** сопоставлением, что и сама раскладка.
  ///
  /// Раньше диалог считал это сам, и две реализации разошлись в двух
  /// местах: при двух правилах с одной меткой он брал первое, тогда как
  /// раскладка от двоякости отказывается, а не найдя местного правила,
  /// подставлял правило **из снимка** — то есть путь с чужой машины,
  /// который здесь не будет записан никогда. Обещание диалога и поведение
  /// восстановления обязаны совпадать, иначе диалог не предупреждение, а
  /// выдумка.
  Map<String, String> previewTargets(Game game, SaveSnapshot snapshot) =>
      _rules.preview(game, snapshot);

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
    final manifest = _package.checkedManifest(
      await _package.open(
        path,
        (archive) async => _package.manifestOf(archive),
      ),
    );
    final rules = _package.rulesOf(manifest);

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
  Future<SaveSnapshot> importPackage(String path, {required Game game}) =>
      store.guard(() => _importPackage(path, game: game));

  Future<SaveSnapshot> _importPackage(String path, {required Game game}) async {
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

    await _package.open(path, (archive) async {
      _checkDeclaredSize(archive);
      for (final file in archive.files) {
        if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;
        if (EvsavePackage.parseEntryName(file.name) == null) continue;
        blobs.add(await _importEntry(file, dir));
      }
    });

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

  /// Предел — тот же, что у плана восстановления, и проверяется до первой
  /// записи: пакет, который не развернуть, незачем переливать в хранилище
  /// гигабайтами.
  void _checkDeclaredSize(Archive archive) {
    var declared = 0;
    for (final file in archive.files) {
      if (file.isFile) declared += file.size;
    }
    if (declared > maxSnapshotBytes) {
      throw SaveException(_l.saveTooLarge(formatBytes(declared)));
    }
  }

  /// Переливает одну запись пакета в хранилище через временный файл.
  Future<SnapshotBlob> _importEntry(ArchiveFile file, Directory dir) async {
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
      return await store.put(file.name, tmp);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
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
      } on Object catch (error) {
        // Битый или чужой файл пропускаем, но не молча: иначе человек не
        // узнал бы, почему пакет с другого устройства не виден в списке.
        _log().write('папка синхронизации: пропущен ${entity.path}', error);
      }
    }
    result.sort((a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt));
    return result;
  }
}

/// Цели восстановления: куда лечь правилам пакета на этом устройстве.
class _ResolvedTargets {
  const _ResolvedTargets({
    required this.byLabel,
    required this.byRuleId,
    required this.unresolved,
  });

  /// Метка правила → путь. Это показывают человеку до восстановления.
  final Map<String, String> byLabel;

  /// Идентификатор правила пакета → куда его файлы лягут.
  final Map<String, RestoreTarget> byRuleId;

  /// Метки правил, которым места на этом устройстве не нашлось.
  final List<String> unresolved;
}
