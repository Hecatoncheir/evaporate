import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../l10n/labels.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../system/app_log.dart';
import 'evsave_package.dart';
import 'offload.dart';
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
  });

  final int filesWritten;
  final int bytesWritten;

  /// label правила -> куда легли файлы на этом устройстве.
  final Map<String, String> targets;

  /// Правила из пакета, которым не нашлось соответствия на этой платформе.
  final List<String> unresolved;

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

  SavePackageInfo withCompatibility({required bool isCompatible}) =>
      SavePackageInfo(
        path: path,
        snapshot: snapshot,
        isCompatible: isCompatible,
      );
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
    Offload? offload,
    this.maxSnapshotBytes = defaultMaxSnapshotBytes,
  }) : _paths = paths ?? AppPaths.instance,
       _renameForRestore = renameForRestore ?? _rename,
       _offload = offload ?? runInIsolate,
       _localizations = localizations ?? _defaultLocalizations,
       _log = log ?? _appLog,
       store = SnapshotStore(
         root: (paths ?? AppPaths.instance).blobsDir,
         offload: offload,
       );

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

  /// Где собирать и разбирать zip — см. [Offload]. Пакет — всегда в
  /// изоляте: он собирается один раз на выгрузку, и заведение изолята
  /// теряется рядом с упаковкой хоть бы и мегабайта.
  final Offload _offload;

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

  /// Возвращает на место сейвы, застрявшие после прерванной раскладки, и
  /// отдаёт копии, оставшиеся рядом с живой целью.
  ///
  /// Снимок и восстановление зовут это сами, но их может и не быть: при
  /// выключенном автоснимке перед запуском игра стартовала без сейвов,
  /// заводила новые — и прогресс навсегда оставался в `.evaporate-old-*`.
  /// Поэтому это зовут ещё перед каждым запуском и один раз на старте.
  Future<List<String>> recoverInterrupted(Game game) =>
      _restore.recoverInterrupted(game);

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

    _rejectOverlapping(game);

    // Сначала обходим файлы, чтобы манифест содержал честные размеры.
    final found = await _collectByRules(game, rules);

    if (found.entries.isEmpty) {
      throw SaveNothingFoundException(_l.saveNothingFound);
    }
    if (found.totalBytes > maxSnapshotBytes) {
      throw SaveException(_l.saveTooLarge(bytesLabel(_l, found.totalBytes)));
    }

    // Своего архива у снимка нет: файлы уходят в хранилище по содержимому,
    // а пакет собирается из ссылок, когда его просят унести наружу.
    // Одинаковые файлы соседних снимков при этом лежат на диске один раз.
    final blobs = <SnapshotBlob>[];
    for (final entry in found.entries) {
      blobs.add(await store.put(entry.archiveName, File(entry.sourcePath)));
    }

    return SaveSnapshot(
      id: _uuid.v4(),
      gameId: game.id,
      gameTitle: game.title,
      createdAt: DateTime.now(),
      deviceName: currentDeviceName(),
      platform: currentPlatformKey(),
      sizeBytes: found.totalBytes,
      archivePath: '',
      rules: found.rules,
      playtime: game.play.playtime,
      note: note,
      fileCount: found.entries.length,
      origin: origin,
      blobs: blobs,
    );
  }

  /// Обходит правила игры и собирает то, что по ним нашлось.
  ///
  /// Правила возвращаются не теми, что были: у сработавшего уточняется
  /// вид (файл или папка), а не сработавшие в снимок не попадают вовсе —
  /// иначе на другом устройстве пришлось бы гадать, почему по правилу
  /// ничего не лежит.
  Future<
    ({List<CollectedFile> entries, List<SavePathRule> rules, int totalBytes})
  >
  _collectByRules(Game game, List<SavePathRule> rules) async {
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

    return (entries: entries, rules: usedRules, totalBytes: totalBytes);
  }

  /// Отказывает, если пути двух правил пересекаются.
  ///
  /// Вложенность прежде ловилась только при восстановлении: снимок
  /// выходил с дублями, а разложить его не удавалось никогда. Лучше
  /// отказать сразу — и словами, которые называют оба правила.
  void _rejectOverlapping(Game game) {
    final profile = game.saveProfile;
    for (final rule in profile.rulesForCurrentPlatform) {
      final other = profile.overlapping(rule, gameDir: game.installDir);
      if (other != null) {
        throw SaveException(_l.saveRulesOverlap(rule.label, other.label));
      }
    }
  }

  /// Собирает настоящий `.evsave` из ссылок на содержимое.
  ///
  /// Пакет обязан оставаться самодостаточным zip: его уносят на другую
  /// машину и читают чужие сборки, которые про здешнее хранилище ничего не
  /// знают и знать не должны.
  ///
  /// Пишется под временным именем рядом и встаёт на место переименованием:
  /// автовыгрузка кладёт пакет под одно и то же имя, и запись прямо в него
  /// при первом же пропавшем блобе стирала вчерашний рабочий пакет, а
  /// клиент синхронизации успевал унести половину нового. Распакованные
  /// блобы лежат у нас, а не в чужой папке, — их клиент унёс бы тоже.
  ///
  /// Сама упаковка идёт в изоляте ([EvsaveJobs.write]): гигабайт сейвов
  /// разжимался из хранилища и сжимался обратно в zip на том же изоляте,
  /// что рисует окно. Здесь остаётся то, что знает хранилище: всё ли
  /// содержимое на месте, — и то, что знает язык: слова для отказа.
  Future<File> _materialize(SaveSnapshot snapshot, String destination) async {
    final target = File(destination);
    await target.parent.create(recursive: true);
    final partial = File(
      p.join(
        target.parent.path,
        '.${p.basename(destination)}.${_uuid.v4()}.part',
      ),
    );
    // Своя папка на каждую выгрузку: записи в ней лежат под номерами, и
    // две выгрузки разом писали бы в одни и те же файлы.
    final staging = Directory(
      p.join(_paths.dataDir, 'export-staging', _uuid.v4()),
    );

    final entries = <PackageEntry>[];
    for (final blob in snapshot.blobs) {
      if (!await store.contains(blob.hash)) {
        throw SaveException(_l.saveArchiveMissing(blob.name));
      }
      entries.add((
        name: blob.name,
        blob: store.pathFor(blob.hash),
        hash: blob.hash,
        size: blob.size,
      ));
    }

    var complete = false;
    try {
      await staging.create(recursive: true);
      await _offload(
        EvsaveJobs.write(
          partial: partial.path,
          manifest: const JsonEncoder.withIndent('  ')
              .convert(snapshot.toManifest()),
          entries: entries,
          staging: staging.path,
        ),
      );
      complete = true;
    } on UnreadableEntry catch (error) {
      // Не развернулось — содержимое уходит из хранилища, как и при
      // раскладке: следующий снимок того же сейва его перепишет.
      if (error.hash != null) await store.discard(error.hash!);
      throw SaveException(_l.saveArchiveReadFailed(error.name));
    } finally {
      await _quietly(() => staging.delete(recursive: true));
      if (!complete) await _quietly(partial.delete);
    }
    return partial.rename(destination);
  }

  /// Уборка, которой не удалось, исходную ошибку не подменяет.
  static Future<void> _quietly(Future<Object?> Function() cleanup) async {
    try {
      await cleanup();
    } on FileSystemException {
      // Нечего убирать или убрать нельзя — дальше идёт своя ошибка.
    }
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
  ///
  /// Копия уходит в [onBackup] **до** замены, а не в отчёте об успехе:
  /// сорвись замена — отчёта нет, копия не заведена нигде, и её содержимое
  /// уносит следующая уборка ровно тогда, когда она нужнее всего.
  Future<RestoreReport> restoreSnapshot({
    required Game game,
    required SaveSnapshot snapshot,
    bool backupCurrent = true,
    bool wipeTarget = false,
    Future<void> Function(SaveSnapshot backup)? onBackup,
  }) => store.guard(() async {
    await _restore.recoverInterrupted(game);
    return _restoreSnapshot(
      game: game,
      snapshot: snapshot,
      backupCurrent: backupCurrent,
      wipeTarget: wipeTarget,
      onBackup: onBackup,
    );
  });

  Future<RestoreReport> _restoreSnapshot({
    required Game game,
    required SaveSnapshot snapshot,
    required bool backupCurrent,
    required bool wipeTarget,
    required Future<void> Function(SaveSnapshot backup)? onBackup,
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
        onBackup: onBackup,
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
        sources: _package
            .entriesOf(
              archive,
              package: snapshot.archivePath,
              offload: _offload,
            )
            .toList(),
        backupCurrent: backupCurrent,
        wipeTarget: wipeTarget,
        onBackup: onBackup,
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
      if (!await store.contains(blob.hash)) {
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
    required Future<void> Function(SaveSnapshot backup)? onBackup,
  }) async {
    final resolved = await _resolveTargets(game, rules);
    if (resolved.byRuleId.isEmpty) {
      throw SaveException(_l.saveNoTargets);
    }

    final plan = _restore.buildPlan(sources, resolved.byRuleId);
    final backup = backupCurrent
        ? await _backupBeforeRestore(game, snapshot)
        : null;
    if (backup != null) await onBackup?.call(backup);
    await _restore.commit(plan, wipeTarget: wipeTarget);

    return RestoreReport(
      filesWritten: plan.entries.length,
      bytesWritten: plan.bytes,
      targets: resolved.byLabel,
      unresolved: resolved.unresolved,
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

    final assigned = _rules.assign(game, manifestRules);
    for (final rule in manifestRules) {
      final local = assigned[rule.id];
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
        // Дата — журнальной функцией, а не по языку: заметка хранится в
        // снимке и уезжает на другие устройства, а `DateFormat` языка
        // требует данных, которые загружает интерфейс, — без него
        // восстановление падало бы на резервной копии.
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

  /// Ляжет ли снимок хоть одним правилом в пути этой игры.
  ///
  /// Тем же сопоставлением, что раскладка: по id, затем по метке. По одной
  /// платформе правил пакета судить нельзя — снятый на Windows ложится в
  /// macOS-путь той же игры по метке, а значок «нет путей» говорил обратное.
  bool fits(Game game, SaveSnapshot snapshot) =>
      _rules.assign(game, snapshot.rules).isNotEmpty;

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
    await _package.open(path, (archive) async => _checkDeclaredSize(archive));

    final blobs = await _importEntries(
      path,
      Directory(p.join(dir.path, '.import-${_uuid.v4()}')),
    );

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
      throw SaveException(_l.saveTooLarge(bytesLabel(_l, declared)));
    }
  }

  /// Переливает записи пакета в хранилище через временные файлы.
  ///
  /// Разбор zip — в изоляте ([EvsaveJobs.unpack]): пакет в гигабайт иначе
  /// разжимался бы на том же изоляте, что рисует окно. Записи сверяются
  /// по длине и CRC там же, тем же [EvsaveJobs.writeVerified], что у
  /// раскладки: дальше, в хранилище, сверяется одна длина, и недоехавший
  /// из папки синхронизации файл лёг бы туда как целый.
  Future<List<SnapshotBlob>> _importEntries(
    String path,
    Directory staging,
  ) async {
    try {
      final entries = await _offload(
        EvsaveJobs.unpack(path: path, staging: staging.path),
      );
      final blobs = <SnapshotBlob>[];
      for (final entry in entries) {
        blobs.add(await store.put(entry.name, File(entry.path)));
        // Уже в хранилище — место под копией отдаём сразу, а не в конце.
        await File(entry.path).delete();
      }
      return blobs;
    } on UnreadableEntry catch (error) {
      throw SaveException(_l.saveArchiveReadFailed(error.name));
    } finally {
      await _quietly(() => staging.delete(recursive: true));
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
  Future<StoreCleanup> collectGarbage(Iterable<SaveSnapshot> alive) =>
      store.collect({
        for (final snapshot in alive)
          for (final blob in snapshot.blobs) blob.hash,
      });

  /// Сканирует папку синхронизации (Dropbox, Syncthing, iCloud) на пакеты
  /// с других устройств.
  ///
  /// Нечитаемое уходит в журнал и в [onSkipped]: массовая загрузка кладёт
  /// его в отчёт провалом. Прежде оно уходило только в журнал, и пакет от
  /// сборки новее давал отчёт «применено: 0» без единой ошибки.
  Future<List<SavePackageInfo>> scanSyncFolder(
    String folder, {
    void Function(String path, Object error)? onSkipped,
  }) async {
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
        onSkipped?.call(entity.path, error);
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
