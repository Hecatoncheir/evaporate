import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';

/// Один файл, отобранный для снимка: откуда взять и под каким именем
/// положить в пакет.
class CollectedFile {
  const CollectedFile({
    required this.sourcePath,
    required this.archiveName,
    required this.size,
  });

  final String sourcePath;

  /// Имя внутри `.evsave`: `data/<ruleId>/<путь внутри правила>`.
  final String archiveName;

  final int size;
}

/// Что лежит там, куда указывает правило сохранений.
///
/// Отдельно от менеджера снимков, потому что это обход диска со своими
/// правилами, а не работа с пакетами: правило указывает и на отдельный
/// файл, и на папку; вложенность не ограничена; системный мусор в сейвы не
/// попадает. Проверяется на одной временной папке — ни zip, ни снимка для
/// этого не нужно.
class SaveCollector {
  const SaveCollector();

  /// Системный мусор не должен попадать в сейвы. Эти файлы меняются сами
  /// по себе и о прогрессе человека не говорят ничего.
  static const skipNames = {'.DS_Store', 'Thumbs.db', 'desktop.ini'};

  /// Файлы, которые войдут в снимок по одному правилу.
  ///
  /// Пусто — по этому пути нет ни файла, ни папки: правило могло прийти с
  /// другого устройства или указывать на игру, в которую ещё не играли.
  Future<List<CollectedFile>> collect(
    SavePathRule rule,
    String resolved,
  ) async {
    final prefix = '${SaveSnapshot.dataPrefix}/${rule.id}';

    final file = File(resolved);
    if (await file.exists()) {
      return [
        CollectedFile(
          sourcePath: resolved,
          archiveName: '$prefix/${p.basename(resolved)}',
          size: await file.length(),
        ),
      ];
    }

    final directory = Directory(resolved);
    if (!await directory.exists()) return const [];

    final entries = <CollectedFile>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (skipNames.contains(name)) continue;
      final relative = p
          .relative(entity.path, from: directory.path)
          .replaceAll(r'\', '/');
      entries.add(
        CollectedFile(
          sourcePath: entity.path,
          archiveName: '$prefix/$relative',
          size: await entity.length(),
        ),
      );
    }
    return entries;
  }

  /// Когда в последний раз менялось то, на что указывает путь.
  ///
  /// `null` — по пути ничего нет. Для папки смотрится всё содержимое, до
  /// самого дна: игра пишет в свой подкаталог, а не в корень правила.
  Future<DateTime?> newestChangeAt(String path) async {
    final file = File(path);
    if (await file.exists()) return (await file.stat()).modified;

    final directory = Directory(path);
    if (!await directory.exists()) return null;

    DateTime? newest;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      if (skipNames.contains(p.basename(entity.path))) continue;
      newest = later(newest, (await entity.stat()).modified);
    }
    return newest;
  }

  /// Позднее из двух времён. `null` означает «ничего не было».
  static DateTime? later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }
}
