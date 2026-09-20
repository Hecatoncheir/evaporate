part of 'save_manager.dart';

/// Проверка пакета, подготовка новых целей и откат файловой транзакции.
/// Ни один исходный путь не изменяется до полной подготовки всех целей.
extension _RestoreTransaction on SaveManager {
  /// Приводит в порядок следы прерванной раскладки у целей игры.
  ///
  /// Раскладка отодвигает цель в `<цель>.evaporate-old-*` и ставит на её
  /// место подготовленное `.<цель>.evaporate-new-*`. Упади приложение между
  /// двумя переименованиями — сейвы остаются только под резервным именем:
  /// игра их не видит, а снимок, снятый следом, вышел бы пустым. Поэтому
  /// перед любой работой с сейвами игры:
  ///
  /// - цели нет, а резервная копия есть — копия возвращается на место;
  /// - заготовки `evaporate-new` убираются: сейвом они не бывают никогда;
  /// - при целой цели резервная копия остаётся: замена могла дойти до
  ///   конца, а могла и нет, и копия бывает единственной прежней версией.
  ///   Её судьбу решает человек, а в журнал уходит, где она лежит.
  Future<void> _recoverInterrupted(Game game) async {
    for (final rule in game.saveProfile.rulesForCurrentPlatform) {
      final target = rule.resolve(gameDir: game.installDir);
      if (target != null) await _recoverTarget(target);
    }
  }

  Future<void> _recoverTarget(String target) async {
    final parent = Directory(p.dirname(target));
    if (!await parent.exists()) return;
    final name = p.basename(target);
    final stranded = <FileSystemEntity>[];
    await for (final entity in parent.list(followLinks: false)) {
      final entry = p.basename(entity.path);
      if (entry.startsWith('.$name.evaporate-new-')) {
        await _dropQuietly(entity);
      } else if (entry.startsWith('$name.evaporate-old-')) {
        stranded.add(entity);
      }
    }
    if (stranded.isEmpty) return;

    final missing =
        await FileSystemEntity.type(target, followLinks: false) ==
        FileSystemEntityType.notFound;
    if (missing) {
      // Самая свежая копия — та, что отодвинули последней.
      stranded.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      await stranded.removeAt(0).rename(target);
      AppLog.instance.write('сейвы возвращены в $target после сбоя');
    }
    for (final left in stranded) {
      AppLog.instance.write('рядом с сейвами осталась копия: ${left.path}');
    }
  }

  Future<void> _dropQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // Не вышло — уберём в другой раз: заготовка не мешает.
    }
  }

  /// Собирает план: какой файл пакета в какое место ляжет.
  ///
  /// План строится целиком до первой записи на диск. Пакет приходит извне,
  /// и половина разобранного пакета хуже, чем неразобранный.
  _RestorePlan _buildRestorePlan(
    Archive archive,
    Map<String, _RestoreTarget> targets,
  ) {
    final plan = _PlanBuilder(this);
    for (final entry in _payloadEntries(archive, targets)) {
      plan.add(entry);
    }
    return plan.build();
  }

  /// Записи пакета, которым есть куда лечь.
  ///
  /// Манифест, папки и правила, которых у этой игры нет, отсеиваются молча
  /// — пакет мог прийти с устройства, где правил больше. А вот ссылка не
  /// отсеивается, а останавливает разбор: в наших пакетах её не бывает, и
  /// чужая уводит запись куда угодно.
  Iterable<_Payload> _payloadEntries(
    Archive archive,
    Map<String, _RestoreTarget> targets,
  ) sync* {
    for (final file in archive.files) {
      if (file.isSymbolicLink) {
        throw SaveException(_l.savePathEscapes(file.name));
      }
      if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;

      final parsed = SaveManager._parseEntryName(file.name);
      if (parsed == null) continue;
      final target = targets[parsed.ruleId];
      if (target == null) continue;
      yield _Payload(file: file, target: target, name: parsed);
    }
  }

  /// Куда ляжет одна запись пакета.
  ///
  /// [sameRule] — сколько записей этого правила уже разобрано. Правило на
  /// один файл описывает ровно один файл: второй означает, что пакет
  /// собран не так, как их пишем мы.
  String _destinationFor(_Payload payload, {required int sameRule}) {
    final parts = _safeRelativeParts(
      payload.name.relativePath,
      payload.file.name,
    );
    if (payload.target.isFile) {
      if (sameRule > 0 || parts.length != 1) {
        throw SaveException(_l.savePathEscapes(payload.file.name));
      }
      return payload.target.path;
    }

    final destination = p.normalize(p.joinAll([payload.target.path, ...parts]));
    if (!p.isWithin(payload.target.path, destination)) {
      throw SaveException(_l.savePathEscapes(payload.file.name));
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
  void _checkTargetsDoNotOverlap(Set<_RestoreTarget> targets) {
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
  Future<void> _commitRestore(
    _RestorePlan plan, {
    required bool wipeTarget,
  }) async {
    // Оба списка нужны и откату, и уборке, поэтому живут здесь, а шаги
    // только дописывают в них.
    final prepared = <_PreparedTarget>[];
    final committed = <_CommittedTarget>[];
    try {
      await _prepareTargets(plan, prepared, wipeTarget: wipeTarget);
      await _swapPreparedIn(prepared, committed);
    } on Object catch (error) {
      await _rollback(committed);
      throw error is SaveException
          ? error
          : SaveException(_l.saveArchiveReadFailed('$error'));
    } finally {
      await _dropPrepared(prepared);
    }
    await _dropBackups(committed);
  }

  /// Собирает замену рядом с каждой целью, не трогая саму цель.
  Future<void> _prepareTargets(
    _RestorePlan plan,
    List<_PreparedTarget> prepared, {
    required bool wipeTarget,
  }) async {
    for (final group in plan.byTarget.entries) {
      final target = group.key;
      final token = SaveManager._uuid.v4();
      final candidatePath = p.join(
        p.dirname(target.path),
        '.${p.basename(target.path)}.evaporate-new-$token',
      );
      prepared.add(_PreparedTarget(target: target, path: candidatePath));

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
    _RestoreTarget target,
    String candidatePath,
    List<_RestoreEntry> entries,
  ) async {
    if (await Directory(target.path).exists()) {
      throw FileSystemException('Expected a file', target.path);
    }
    // Ровно одна запись на такую цель — это проверено при сборке плана.
    await _writeArchiveFile(entries.single.archiveFile, candidatePath);
  }

  /// Собирает новую папку целиком: при слиянии — поверх копии нынешней,
  /// при замене — с чистого места.
  Future<void> _prepareDirectoryTarget(
    _RestoreTarget target,
    String candidatePath,
    List<_RestoreEntry> entries, {
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
      await _writeArchiveFile(
        entry.archiveFile,
        p.join(candidate.path, relative),
      );
    }
  }

  /// Ставит подготовленное на место цели, отодвинув прежнее в резервную
  /// копию. Сорвись переименование — отодвинутое возвращается тут же.
  Future<void> _swapPreparedIn(
    List<_PreparedTarget> prepared,
    List<_CommittedTarget> committed,
  ) async {
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
  }

  /// Возвращает уже заменённые цели к прежнему виду — в обратном порядке,
  /// чтобы каждая следующая находила своё место свободным.
  Future<void> _rollback(List<_CommittedTarget> committed) async {
    for (final item in committed.reversed) {
      if (await _entityExists(item.target)) {
        await _deleteEntity(item.target, item.target.path);
      }
      if (item.backupPath != null) {
        await _renameEntity(item.target, item.backupPath!, item.target.path);
      }
    }
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

/// Запись пакета вместе с правилом, к которому она относится.
class _Payload {
  const _Payload({
    required this.file,
    required this.target,
    required this.name,
  });

  final ArchiveFile file;
  final _RestoreTarget target;
  final _EntryName name;
}

/// Строит план и сам сторожит его правила.
///
/// Счётчики — сколько записей у правила, какие места уже заняты, сколько
/// всего байт — держит он, а не тот, кто перебирает пакет: иначе они
/// расползаются по циклу, и увидеть, что именно проверяется, можно только
/// прочитав его целиком.
class _PlanBuilder {
  _PlanBuilder(this._saves);

  final SaveManager _saves;
  final List<_RestoreEntry> _entries = [];
  final Set<String> _destinations = {};
  final Map<String, int> _perRule = {};
  int _bytes = 0;

  void add(_Payload payload) {
    final ruleId = payload.name.ruleId;
    final destination = _saves._destinationFor(
      payload,
      sameRule: _perRule[ruleId] ?? 0,
    );
    _perRule[ruleId] = (_perRule[ruleId] ?? 0) + 1;

    // Два файла пакета в одно место — спор о том, чьё содержимое окажется
    // на диске. Решать его молча нельзя.
    if (!_destinations.add(destination)) {
      throw SaveException(_saves._l.saveArchiveReadFailed(payload.file.name));
    }

    _bytes += payload.file.size;
    if (_bytes > _saves.maxSnapshotBytes) {
      throw SaveException(_saves._l.saveTooLarge(formatBytes(_bytes)));
    }
    _entries.add(
      _RestoreEntry(
        archiveFile: payload.file,
        target: payload.target,
        destination: destination,
      ),
    );
  }

  _RestorePlan build() {
    _saves._checkTargetsDoNotOverlap({
      for (final entry in _entries) entry.target,
    });
    if (_entries.isEmpty) {
      throw SaveNothingFoundException(_saves._l.saveNothingFound);
    }
    return _RestorePlan(entries: _entries, bytes: _bytes);
  }
}
