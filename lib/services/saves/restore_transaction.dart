import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../system/app_log.dart';
import 'evsave_package.dart';
import 'save_exception.dart';

/// Откуда берутся байты одного файла снимка.
///
/// Источников два — запись пакета и файл хранилища по содержимому, — а
/// раскладка одна. Она самое опасное место приложения: второй её
/// реализации быть не должно, поэтому различается ровно то, откуда байты
/// текут и чем проверяется, что дотекли целиком.
abstract class RestoreSource {
  /// Имя внутри пакета: `data/<ruleId>/<путь внутри правила>`. По нему
  /// файл и находит своё место, откуда бы он ни брался.
  String get name;

  int get size;

  /// Кладёт содержимое по пути [path] — и отвечает за то, что положенное
  /// совпадает с обещанным.
  Future<void> writeTo(String path);
}

/// Проверка пакета, подготовка новых целей и откат файловой транзакции.
/// Ни один исходный путь не изменяется до полной подготовки всех целей.
///
/// Своим классом, а не расширением менеджера: это единственное место, где
/// приложение трогает **чужие сохранения на месте**, и у него своя цена
/// ошибки. Всё, что ему нужно от менеджера, — переводы, предел размера и
/// переименование (подменяемое в тестах, чтобы проверить откат).
class RestoreTransaction {
  RestoreTransaction({
    required this._localizations,
    required this.maxSnapshotBytes,
    required Future<FileSystemEntity> Function(FileSystemEntity, String) rename,
    AppLog Function()? log,
  }) : _renameForRestore = rename,
       _log = log ?? _appLog;

  /// Откуда брать переводы: отказы отсюда доходят до человека словами.
  final L Function() _localizations;

  /// Куда писать о найденных следах прерванной раскладки. Функцией — как
  /// `L Function()`: в тестах подменяется без правки глобала, а глобал
  /// один на весь прогон и достаётся соседнему файлу.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;

  L get _l => _localizations();

  /// Предел размера снимка: предохранитель от «указал папку игры целиком».
  final int maxSnapshotBytes;

  /// Переименование цели. Подменяется в тестах: сорвавшаяся замена — то
  /// самое, ради чего вся транзакция и заведена.
  final Future<FileSystemEntity> Function(FileSystemEntity, String)
  _renameForRestore;

  static const _uuid = Uuid();

  /// Заготовки и отодвинутые копии, которые прямо сейчас ведёт раскладка.
  ///
  /// Возврат застрявших сейвов ([recoverInterrupted]) их не трогает. Без
  /// этого он удалял **любую** заготовку `evaporate-new` — и ту, что в этот
  /// миг наполняла параллельная раскладка, — а между двумя переименованиями
  /// видел пропавшую цель и возвращал на её место живую копию. Очередь по
  /// игре здесь не годится: снимок перед восстановлением сам идёт через
  /// тот же менеджер и ждал бы сам себя.
  final _live = <String>{};

  void _own(String path, List<String> owned) {
    final normalized = p.normalize(path);
    _live.add(normalized);
    owned.add(normalized);
  }

  /// Имя, под которое отодвигается прежняя цель.
  ///
  /// Время — в имени, а не в дате файла: переименование её не меняет, и
  /// «последняя отодвинутая» по `modified` оказывалась той, что дольше всех
  /// не трогали. Микросекунды с нулями слева, чтобы имена сравнивались как
  /// числа; `uuid` — чтобы две раскладки в одну микросекунду не столкнулись.
  static String backupPathFor(String target, DateTime at) {
    final stamp = at.microsecondsSinceEpoch.toString().padLeft(20, '0');
    return '$target.evaporate-old-$stamp-${_uuid.v4()}';
  }

  /// Когда отодвинута копия; у копий прежних сборок времени в имени нет, и
  /// они считаются старше любой новой.
  static int _movedAt(String path) {
    final match = RegExp(r'\.evaporate-old-(\d{20})-').firstMatch(path);
    return match == null ? -1 : int.parse(match.group(1)!);
  }

  /// Приводит в порядок следы прерванной раскладки у целей игры.
  ///
  /// Раскладка отодвигает цель в `<цель>.evaporate-old-*` и ставит на её
  /// место подготовленное `.<цель>.evaporate-new-*`. Упади приложение между
  /// двумя переименованиями — сейвы остаются только под резервным именем:
  /// игра их не видит, а снимок, снятый следом, вышел бы пустым. Поэтому
  /// перед любой работой с сейвами игры — и перед каждым её запуском:
  ///
  /// - цели нет, а резервная копия есть — копия возвращается на место;
  /// - заготовки `evaporate-new` убираются: сейвом они не бывают никогда;
  /// - при целой цели резервная копия остаётся: замена могла дойти до
  ///   конца, а могла и нет, и копия бывает единственной прежней версией.
  ///   Её судьбу решает человек — поэтому такие копии возвращаются, чтобы
  ///   сказать о них словами, а не только строкой в журнале.
  ///
  /// Всё, что ведёт идущая сейчас раскладка ([_live]), не трогается.
  Future<List<String>> recoverInterrupted(Game game) async {
    final left = <String>[];
    for (final rule in game.saveProfile.rulesForCurrentPlatform) {
      final target = rule.resolve(gameDir: game.installDir);
      if (target != null) left.addAll(await _recoverTarget(target));
    }
    return left;
  }

  Future<List<String>> _recoverTarget(String target) async {
    final parent = Directory(p.dirname(target));
    if (!await parent.exists()) return const [];
    final name = p.basename(target);
    final stranded = <FileSystemEntity>[];
    await for (final entity in parent.list(followLinks: false)) {
      if (_live.contains(p.normalize(entity.path))) continue;
      final entry = p.basename(entity.path);
      if (entry.startsWith('.$name.evaporate-new-')) {
        await _dropQuietly(entity);
      } else if (entry.startsWith('$name.evaporate-old-')) {
        stranded.add(entity);
      }
    }
    if (stranded.isEmpty) return const [];

    final missing =
        await FileSystemEntity.type(target, followLinks: false) ==
        FileSystemEntityType.notFound;
    if (missing) {
      // Самая свежая копия — та, что отодвинули последней.
      stranded.sort((a, b) => _movedAt(b.path).compareTo(_movedAt(a.path)));
      await stranded.removeAt(0).rename(target);
      _log().write('сейвы возвращены в $target после сбоя');
    }
    for (final copy in stranded) {
      _log().write('рядом с сейвами осталась копия: ${copy.path}');
    }
    return [for (final copy in stranded) copy.path];
  }

  Future<void> _dropQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // Не вышло — уберём в другой раз: заготовка не мешает.
    }
  }

  /// Собирает план: какой файл снимка в какое место ляжет.
  ///
  /// План строится целиком до первой записи на диск. Снимок мог прийти
  /// извне, а половина разобранного пакета хуже, чем неразобранный.
  RestorePlan buildPlan(
    Iterable<RestoreSource> sources,
    Map<String, RestoreTarget> targets,
  ) {
    final plan = _PlanBuilder(this);
    for (final entry in _payloadEntries(sources, targets)) {
      plan.add(entry);
    }
    return plan.build();
  }

  /// Файлы снимка, которым есть куда лечь.
  ///
  /// Правила, которых у этой игры нет, отсеиваются молча: снимок мог
  /// прийти с устройства, где путей больше.
  Iterable<RestorePayload> _payloadEntries(
    Iterable<RestoreSource> sources,
    Map<String, RestoreTarget> targets,
  ) sync* {
    for (final source in sources) {
      final parsed = EvsavePackage.parseEntryName(source.name);
      if (parsed == null) continue;
      final target = targets[parsed.ruleId];
      if (target == null) continue;
      yield RestorePayload(source: source, target: target, name: parsed);
    }
  }

  /// Куда ляжет одна запись пакета.
  ///
  /// [sameRule] — сколько записей этого правила уже разобрано. Правило на
  /// один файл описывает ровно один файл: второй означает, что пакет
  /// собран не так, как их пишем мы.
  String destinationFor(RestorePayload payload, {required int sameRule}) {
    final parts = _safeRelativeParts(
      payload.name.relativePath,
      payload.source.name,
    );
    if (payload.target.isFile) {
      if (sameRule > 0 || parts.length != 1) {
        throw SaveException(_l.savePathEscapes(payload.source.name));
      }
      return payload.target.path;
    }

    final destination = p.normalize(p.joinAll([payload.target.path, ...parts]));
    if (!p.isWithin(payload.target.path, destination)) {
      throw SaveException(_l.savePathEscapes(payload.source.name));
    }
    return destination;
  }

  /// Разбирает путь внутри пакета на части и убеждается, что он никуда не
  /// уводит: пакет приходит извне, и `../..` в нём — обычное дело.
  List<String> _safeRelativeParts(String relativePath, String entryName) {
    final relative = relativePath.replaceAll(r'\', '/');
    final parts = relative.split('/');
    final escapes =
        relative.isEmpty ||
        p.posix.isAbsolute(relative) ||
        p.windows.isAbsolute(relative) ||
        // На Windows двоеточие уводит на другой диск, а не именует файл.
        (Platform.isWindows && relative.contains(':')) ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..');
    if (escapes) throw SaveException(_l.savePathEscapes(entryName));
    return parts;
  }

  /// Цели не должны лежать одна в другой: замена идёт папкой целиком, и
  /// вложенная цель исчезла бы вместе со старым содержимым внешней.
  void checkTargetsDoNotOverlap(Set<RestoreTarget> targets) {
    final paths = [for (final target in targets) target.path];
    for (var i = 0; i < paths.length; i++) {
      for (var j = i + 1; j < paths.length; j++) {
        final a = paths[i];
        final b = paths[j];
        if (p.equals(a, b) || p.isWithin(a, b) || p.isWithin(b, a)) {
          throw SaveException(_l.savePathEscapes('$a / $b'));
        }
      }
    }
  }

  /// Раскладывает пакет по местам так, чтобы неудача на любом шаге не
  /// оставила человека без сохранений.
  ///
  /// Порядок шагов и есть возможность откатиться: сначала рядом с каждой
  /// целью собирается её замена, потом прежнее отодвигается в резервную
  /// копию, и только в самом конце копии убираются.
  Future<void> commit(RestorePlan plan, {required bool wipeTarget}) async {
    // Оба списка нужны и откату, и уборке, поэтому живут здесь, а шаги
    // только дописывают в них.
    final prepared = <_PreparedTarget>[];
    final committed = <_CommittedTarget>[];
    final owned = <String>[];
    try {
      await _commit(plan, prepared, committed, owned, wipeTarget: wipeTarget);
    } finally {
      _live.removeAll(owned);
    }
  }

  Future<void> _commit(
    RestorePlan plan,
    List<_PreparedTarget> prepared,
    List<_CommittedTarget> committed,
    List<String> owned, {
    required bool wipeTarget,
  }) async {
    try {
      await _prepareTargets(plan, prepared, owned, wipeTarget: wipeTarget);
      await _swapPreparedIn(prepared, committed, owned);
    } on Object catch (error) {
      final stranded = await _rollback(committed);
      final cause = error is SaveException
          ? error.message
          : _l.saveArchiveReadFailed('$error');
      if (stranded.isEmpty) {
        throw error is SaveException ? error : SaveException(cause);
      }
      throw SaveException(
        '$cause ${_l.saveRollbackStranded(stranded.join(', '))}',
      );
    } finally {
      await _dropPrepared(prepared);
    }
    await _dropBackups(committed);
  }

  /// Собирает замену рядом с каждой целью, не трогая саму цель.
  Future<void> _prepareTargets(
    RestorePlan plan,
    List<_PreparedTarget> prepared,
    List<String> owned, {
    required bool wipeTarget,
  }) async {
    for (final group in plan.byTarget.entries) {
      final target = group.key;
      final token = _uuid.v4();
      final candidatePath = p.join(
        p.dirname(target.path),
        '.${p.basename(target.path)}.evaporate-new-$token',
      );
      prepared.add(_PreparedTarget(target: target, path: candidatePath));
      _own(candidatePath, owned);

      // По ссылке мы писали бы неизвестно куда — мимо цели.
      if ((await FileSystemEntity.type(target.path, followLinks: false)) ==
          FileSystemEntityType.link) {
        throw SaveException(_l.savePathEscapes(target.path));
      }
      await Directory(p.dirname(target.path)).create(recursive: true);

      if (target.isFile) {
        await _prepareFileTarget(target, candidatePath, group.value);
      } else {
        await _prepareDirectoryTarget(
          target,
          candidatePath,
          group.value,
          wipeTarget: wipeTarget,
        );
      }
    }
  }

  Future<void> _prepareFileTarget(
    RestoreTarget target,
    String candidatePath,
    List<RestoreEntry> entries,
  ) async {
    if (await Directory(target.path).exists()) {
      throw FileSystemException('Expected a file', target.path);
    }
    // Ровно одна запись на такую цель — это проверено при сборке плана.
    await entries.single.source.writeTo(candidatePath);
  }

  /// Собирает новую папку целиком: при слиянии — поверх копии нынешней,
  /// при замене — с чистого места.
  Future<void> _prepareDirectoryTarget(
    RestoreTarget target,
    String candidatePath,
    List<RestoreEntry> entries, {
    required bool wipeTarget,
  }) async {
    if (await File(target.path).exists()) {
      throw FileSystemException('Expected a directory', target.path);
    }
    final candidate = Directory(candidatePath);
    await candidate.create(recursive: true);
    if (!wipeTarget && await Directory(target.path).exists()) {
      await _copyDirectory(Directory(target.path), candidate);
    }
    for (final entry in entries) {
      final relative = p.relative(entry.destination, from: target.path);
      await entry.source.writeTo(p.join(candidate.path, relative));
    }
  }

  /// Ставит подготовленное на место цели, отодвинув прежнее в резервную
  /// копию. Сорвись переименование — отодвинутое возвращается тут же.
  Future<void> _swapPreparedIn(
    List<_PreparedTarget> prepared,
    List<_CommittedTarget> committed,
    List<String> owned,
  ) async {
    for (final item in prepared) {
      final backupPath = backupPathFor(item.target.path, DateTime.now());
      _own(backupPath, owned);
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
  }

  /// Возвращает уже заменённые цели к прежнему виду — в обратном порядке,
  /// чтобы каждая следующая находила своё место свободным.
  ///
  /// Каждая цель — в своём `try`: на Windows свежезаписанное держит
  /// антивирус, и одно исключение, вылетев отсюда, оставляло остальные
  /// цели неоткаченными, а исходную причину сбоя — потерянной. Возвращает
  /// резервные копии, которые на место не встали: прежние сейвы лежат там,
  /// и человек должен узнать где.
  Future<List<String>> _rollback(List<_CommittedTarget> committed) async {
    final stranded = <String>[];
    for (final item in committed.reversed) {
      final backup = item.backupPath;
      try {
        if (await _entityExists(item.target)) {
          await _deleteEntity(item.target, item.target.path);
        }
        if (backup != null) {
          await _renameEntity(item.target, backup, item.target.path);
        }
      } on Object catch (error) {
        _log().write('откат раскладки: ${item.target.path}', error);
        if (backup != null) stranded.add(backup);
      }
    }
    return stranded;
  }

  /// Убирает подготовленное, чем бы дело ни кончилось: при удаче оно уже
  /// переименовано в цель, при неудаче — просто лишнее.
  Future<void> _dropPrepared(List<_PreparedTarget> prepared) async {
    for (final item in prepared) {
      try {
        await _deleteEntity(item.target, item.path);
      } on FileSystemException {
        // Подготовленный файл не является единственной копией сейва.
        // Ошибка его уборки не должна запускать откат завершённой операции.
      }
    }
  }

  /// Убирает резервные копии: все цели заменены, откатываться уже некуда.
  ///
  /// Ошибка удаления старой копии не должна удалить новые сохранения.
  Future<void> _dropBackups(List<_CommittedTarget> committed) async {
    for (final item in committed) {
      if (item.backupPath == null) continue;
      try {
        await _deleteEntity(item.target, item.backupPath!);
      } on FileSystemException catch (error) {
        // Оставляем старую копию рядом с целью: это безопаснее её потери.
        // Но не молча — иначе копия лежала бы там годами без объяснений.
        _log().write('не убрана прежняя копия ${item.backupPath}', error);
      }
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

  Future<bool> _entityExists(RestoreTarget target) => target.isFile
      ? File(target.path).exists()
      : Directory(target.path).exists();

  Future<void> _renameEntity(RestoreTarget target, String from, String to) =>
      _renameForRestore(target.isFile ? File(from) : Directory(from), to);

  Future<void> _deleteEntity(RestoreTarget target, String path) async {
    if (target.isFile) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } else {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}

class RestoreTarget {
  const RestoreTarget({required this.path, required this.isFile});

  final String path;
  final bool isFile;

  @override
  bool operator ==(Object other) =>
      other is RestoreTarget && other.path == path && other.isFile == isFile;

  @override
  int get hashCode => Object.hash(path, isFile);
}

class RestoreEntry {
  const RestoreEntry({
    required this.source,
    required this.target,
    required this.destination,
  });

  final RestoreSource source;
  final RestoreTarget target;
  final String destination;
}

class RestorePlan {
  const RestorePlan({required this.entries, required this.bytes});

  final List<RestoreEntry> entries;
  final int bytes;

  Map<RestoreTarget, List<RestoreEntry>> get byTarget {
    final result = <RestoreTarget, List<RestoreEntry>>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.target, () => []).add(entry);
    }
    return result;
  }
}

class _PreparedTarget {
  const _PreparedTarget({required this.target, required this.path});

  final RestoreTarget target;
  final String path;
}

class _CommittedTarget {
  const _CommittedTarget({required this.target, required this.backupPath});

  final RestoreTarget target;
  final String? backupPath;
}

/// Запись пакета вместе с правилом, к которому она относится.
class RestorePayload {
  const RestorePayload({
    required this.source,
    required this.target,
    required this.name,
  });

  final RestoreSource source;
  final RestoreTarget target;
  final EntryName name;
}

/// Строит план и сам сторожит его правила.
///
/// Счётчики — сколько записей у правила, какие места уже заняты, сколько
/// всего байт — держит он, а не тот, кто перебирает пакет: иначе они
/// расползаются по циклу, и увидеть, что именно проверяется, можно только
/// прочитав его целиком.
class _PlanBuilder {
  _PlanBuilder(this._saves);

  final RestoreTransaction _saves;
  final List<RestoreEntry> _entries = [];
  final Set<String> _destinations = {};
  final Map<String, int> _perRule = {};
  int _bytes = 0;

  void add(RestorePayload payload) {
    final ruleId = payload.name.ruleId;
    final destination = _saves.destinationFor(
      payload,
      sameRule: _perRule[ruleId] ?? 0,
    );
    _perRule[ruleId] = (_perRule[ruleId] ?? 0) + 1;

    // Два файла пакета в одно место — спор о том, чьё содержимое окажется
    // на диске. Решать его молча нельзя.
    if (!_destinations.add(destination)) {
      throw SaveException(_saves._l.saveArchiveReadFailed(payload.source.name));
    }

    _bytes += payload.source.size;
    if (_bytes > _saves.maxSnapshotBytes) {
      throw SaveException(_saves._l.saveTooLarge(formatBytes(_bytes)));
    }
    _entries.add(
      RestoreEntry(
        source: payload.source,
        target: payload.target,
        destination: destination,
      ),
    );
  }

  RestorePlan build() {
    _saves.checkTargetsDoNotOverlap({
      for (final entry in _entries) entry.target,
    });
    if (_entries.isEmpty) {
      throw SaveNothingFoundException(_saves._l.saveNothingFound);
    }
    return RestorePlan(entries: _entries, bytes: _bytes);
  }
}
