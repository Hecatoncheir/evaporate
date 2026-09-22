import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import 'offload.dart';
import 'restore_transaction.dart';
import 'save_exception.dart';

/// Пакет `.evsave`: открыть, прочитать манифест, разобрать имена записей.
///
/// Отдельно от менеджера снимков, потому что это работа с **чужим** файлом.
/// Пакет приходит извне — с другого устройства, из мессенджера, с флешки, —
/// и все правила здесь об одном: разобрать его, ничего не додумав за него и
/// ничего не сломав, если он окажется не тем.
class EvsavePackage {
  EvsavePackage({L Function()? localizations})
    : _localizations = localizations ?? _defaultLocalizations;

  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  /// Открывает пакет, отдаёт его [use] и закрывает всё, что открыл.
  ///
  /// Закрывать приходится двоих: архив держит потоки своих записей, а
  /// разборщик — поток самого файла, и `Archive.clear` его не трогает. На
  /// Windows незакрытый поток держит пакет запертым до выхода из
  /// приложения: ни удалить битый, ни заменить исправным, ни убрать
  /// временный пакет после восстановления.
  Future<T> open<T>(
    String path,
    Future<T> Function(Archive archive) use,
  ) async {
    if (!await File(path).exists()) {
      throw SaveException(_l.fileNotFound(path));
    }
    final input = InputFileStream(path);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } on Object catch (error) {
        throw SaveException(_l.saveArchiveReadFailed('$error'));
      }
      try {
        return await use(archive);
      } finally {
        await archive.clear();
      }
    } finally {
      await input.close();
    }
  }

  Map<String, dynamic>? manifestOf(Archive archive) {
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

  static EntryName? parseEntryName(String name) {
    final normalized = name.replaceAll(r'\', '/');
    final parts = normalized.split('/');
    if (parts.length < 3) return null;
    if (parts.first != SaveSnapshot.dataPrefix) return null;
    return EntryName(parts[1], parts.sublist(2).join('/'));
  }

  /// Записи пакета, из которых складывается снимок.
  ///
  /// Манифест и папки пропускаются, а вот ссылка не пропускается, а
  /// останавливает разбор: в наших пакетах её не бывает, и чужая уводит
  /// запись куда угодно.
  ///
  /// [package] и [offload] — чтобы крупную запись разжать в изоляте: он
  /// откроет пакет сам, по пути, — открытый здесь архив туда не переслать.
  Iterable<RestoreSource> entriesOf(
    Archive archive, {
    String? package,
    Offload? offload,
    Map<String, DateTime> modified = const {},
  }) sync* {
    for (final file in archive.files) {
      if (file.isSymbolicLink) {
        throw SaveException(_l.savePathEscapes(file.name));
      }
      if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;
      yield ArchiveEntrySource(
        file,
        localizations: _localizations,
        package: package,
        offload: offload,
        modified: modified[file.name],
      );
    }
  }

  /// Манифест, с которым можно работать дальше.
  ///
  /// Оба отказа — человеку, а не в журнал: пакет пришёл извне, и «это не
  /// наш пакет» с «эту версию мы не читаем» он должен различать. Версии
  /// сверяются по множеству [SaveSnapshot.readableFormats], а не с
  /// текущей: пакеты переживают версии приложения.
  Map<String, dynamic> checkedManifest(Map<String, dynamic>? manifest) {
    if (manifest == null) {
      throw SaveException(_l.saveNotEvaporatePackage);
    }
    if (!SaveSnapshot.readableFormats.contains(manifest['format'])) {
      throw SaveException(_l.saveUnsupportedVersion('${manifest['format']}'));
    }
    return manifest;
  }

  List<SavePathRule> rulesOf(Map<String, dynamic> manifest) {
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
}

class EntryName {
  const EntryName(this.ruleId, this.relativePath);

  final String ruleId;
  final String relativePath;
}

/// Файл, лежащий в самом пакете.
///
/// Записанное сверяется по длине и CRC из заголовка zip: пакет приходит
/// извне, и обрыв на середине выглядит как обычный файл.
class ArchiveEntrySource implements RestoreSource {
  ArchiveEntrySource(
    this._file, {
    required this._localizations,
    this._package,
    this._offload,
    this.modified,
  });

  final ArchiveFile _file;
  final L Function() _localizations;

  /// Путь к пакету и где разжимать крупное. Без них запись разжимается
  /// на месте, из уже открытого архива.
  final String? _package;
  final Offload? _offload;

  L get _l => _localizations();

  @override
  String get name => _file.name;

  @override
  int get size => _file.size;

  /// Из манифеста ([SaveSnapshot.manifestModifiedKey]), а не из записи
  /// zip: там время местное и без пояса.
  @override
  final DateTime? modified;

  @override
  Future<void> writeTo(String path) async {
    final package = _package;
    final offload = _offload;
    final whole = package != null && offload != null && size >= offloadFromBytes
        ? await offload(
            EvsaveJobs.extractOne(package: package, name: name, target: path),
          )
        : await EvsaveJobs.writeVerified(_file, path);
    if (!whole) {
      throw SaveException(_l.saveArchiveReadFailed(_file.name));
    }
  }
}

/// Одна запись будущего пакета: имя в zip и сжатое содержимое в хранилище.
typedef PackageEntry = ({String name, String blob, String hash, int size});

/// Запись пакета, разложенная во временный файл.
typedef UnpackedEntry = ({String name, String path});

/// Запись, которую не удалось прочитать: обрыв, чужая CRC, битый gzip.
///
/// Своим классом, а не `SaveException`: бросается в изоляте, где нет
/// переводов, а слова к нему подбирает тот, кто изолят заводил.
class UnreadableEntry implements Exception {
  const UnreadableEntry(this.name, {this.hash});

  final String name;

  /// Содержимое хранилища, которое не развернулось, — если дело в нём.
  final String? hash;

  @override
  String toString() => 'UnreadableEntry($name)';
}

/// Работа с байтами пакета, которую можно отдать изоляту.
///
/// Задачи собираются статикой из строк и списков: замыкание, пересылаемое
/// в изолят, не должно тянуть с собой ни менеджера, ни хранилища.
abstract final class EvsaveJobs {
  /// Собирает пакет в [partial]: манифест и все записи, развёрнутые из
  /// хранилища по одной через [staging].
  static Future<void> Function() write({
    required String partial,
    required String manifest,
    required List<PackageEntry> entries,
    required String staging,
  }) => () async {
    final encoder = ZipFileEncoder()..create(partial);
    try {
      encoder.addArchiveFile(
        ArchiveFile.string(SaveSnapshot.manifestEntry, manifest),
      );
      for (final (index, entry) in entries.indexed) {
        await _addEntry(
          encoder,
          entry,
          staged: '$staging${Platform.pathSeparator}$index.part',
        );
      }
    } finally {
      await encoder.close();
    }
  };

  /// Кладёт одну запись в пакет через развёрнутую копию [staged] и убирает
  /// копию: снимок может весить гигабайты, и держать их разом нечем.
  static Future<void> _addEntry(
    ZipFileEncoder encoder,
    PackageEntry entry, {
    required String staged,
  }) async {
    final file = File(staged);
    try {
      await _gunzip(entry, file);
      await encoder.addFile(file, entry.name);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Разворачивает содержимое хранилища и сверяет длину: обрезанный gzip
  /// разжимается и без ошибки, только короче, — и в пакет, который унесут
  /// на другую машину, лёг бы обрывок под видом сейва.
  static Future<void> _gunzip(PackageEntry entry, File staged) async {
    try {
      await File(entry.blob)
          .openRead()
          .transform(gzip.decoder)
          .pipe(staged.openWrite());
    } on FormatException {
      throw UnreadableEntry(entry.name, hash: entry.hash);
    }
    if (await staged.length() != entry.size) {
      throw UnreadableEntry(entry.name, hash: entry.hash);
    }
  }

  /// Раскладывает записи данных пакета [path] по временным файлам в
  /// [staging] — под номерами, а не под именами из пакета: имя пришло
  /// извне и может уводить за пределы папки.
  static Future<List<UnpackedEntry>> Function() unpack({
    required String path,
    required String staging,
  }) => () async {
    await Directory(staging).create(recursive: true);
    return _withArchive(path, (archive) => _unpackAll(archive, staging));
  };

  static Future<List<UnpackedEntry>> _unpackAll(
    Archive archive,
    String staging,
  ) async {
    final out = <UnpackedEntry>[];
    for (final file in archive.files.where(_isData)) {
      final target = '$staging${Platform.pathSeparator}${out.length}';
      if (!await writeVerified(file, target)) throw UnreadableEntry(file.name);
      out.add((name: file.name, path: target));
    }
    return out;
  }

  /// Запись данных снимка: не манифест, не папка и с разбираемым именем.
  static bool _isData(ArchiveFile file) =>
      file.isFile &&
      file.name != SaveSnapshot.manifestEntry &&
      EvsavePackage.parseEntryName(file.name) != null;

  /// Открывает пакет в изоляте, отдаёт его [use] и закрывает оба потока —
  /// архива и файла, как и [EvsavePackage.open] на главном.
  static Future<T> _withArchive<T>(
    String path,
    Future<T> Function(Archive archive) use,
  ) async {
    final input = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      try {
        return await use(archive);
      } finally {
        await archive.clear();
      }
    } finally {
      await input.close();
    }
  }

  /// Разжимает одну запись пакета [package] в [target] со сверкой.
  ///
  /// Пакет открывается заново: открытый архив держит поток файла, и в
  /// изолят его не переслать. Заход по центральному каталогу дёшев, а
  /// зовут это только ради крупных записей.
  static Future<bool> Function() extractOne({
    required String package,
    required String name,
    required String target,
  }) =>
      () => _withArchive(package, (archive) async {
        final file = archive.findFile(name);
        return file != null && await writeVerified(file, target);
      });

  /// Пишет запись пакета в файл и сверяет записанное с длиной и CRC из
  /// заголовка zip: пакет приходит извне, и обрыв на середине выглядит
  /// как обычный файл.
  static Future<bool> writeVerified(ArchiveFile file, String path) async {
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
    return size == file.size && (file.crc32 == null || crc == file.crc32);
  }
}
