import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
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
  Iterable<RestoreSource> entriesOf(Archive archive) sync* {
    for (final file in archive.files) {
      if (file.isSymbolicLink) {
        throw SaveException(_l.savePathEscapes(file.name));
      }
      if (!file.isFile || file.name == SaveSnapshot.manifestEntry) continue;
      yield ArchiveEntrySource(file, localizations: _localizations);
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
  ArchiveEntrySource(this._file, {required this._localizations});

  final ArchiveFile _file;
  final L Function() _localizations;

  L get _l => _localizations();

  @override
  String get name => _file.name;

  @override
  int get size => _file.size;

  @override
  Future<void> writeTo(String path) async {
    final outFile = File(path);
    await outFile.parent.create(recursive: true);
    final output = OutputFileStream(path);
    try {
      _file.writeContent(output);
    } finally {
      await output.close();
    }
    var crc = 0;
    var size = 0;
    await for (final chunk in outFile.openRead()) {
      size += chunk.length;
      crc = getCrc32(chunk, crc);
    }
    if (size != _file.size || (_file.crc32 != null && crc != _file.crc32)) {
      throw SaveException(_l.saveArchiveReadFailed(_file.name));
    }
  }
}
