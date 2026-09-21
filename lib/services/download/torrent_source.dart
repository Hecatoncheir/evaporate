import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;

import 'torrent_file.dart';

/// Раздача просит записать файл мимо папки загрузки.
///
/// Отдельный тип, а не общая ошибка разбора: причина здесь не в испорченном
/// файле, а в его содержимом, и сказать об этом человеку надо иначе.
class UnsafeTorrentException implements Exception {
  UnsafeTorrentException(this.path);

  /// Путь, из-за которого раздача отклонена.
  final String path;

  @override
  String toString() => 'Небезопасный путь в раздаче: $path';
}

/// Чтение раздачи в модель движка.
///
/// Стоит между [TorrentFile], который знает формат и байты, и движком,
/// который знает задачи: здесь байты становятся моделью `dtorrent_task_v2`
/// — с пересчитанным infohash и проверенными путями.
///
/// Отдельно от движка, потому что к нему не относится: разбор формата не
/// трогает ни одной задачи, ни одного соединения, и проверять его нужно
/// без движка вовсе.
class TorrentSource {
  const TorrentSource._();

  /// Читает `.torrent` с диска.
  static Future<dt.TorrentModel> fromFile(String path) async =>
      fromBytes(await File(path).readAsBytes());

  /// Разбирает `.torrent`, пересчитывая infohash по байтам info-словаря.
  ///
  /// Разборщик библиотеки свой infohash не считает, а угадывает: ищет в файле
  /// байты `info` и закрывающую скобку, принимая за границы словаря первые
  /// же `d` и `e` — а они сплошь и рядом попадаются внутри двоичных хешей
  /// кусков. На настоящей раздаче он промахивается всегда, и с промахнувшимся
  /// хешем раздачу не узнают ни трекер, ни пир. Заодно возвращаем имени
  /// кириллицу: там оно читается как латиница, байт за символ.
  static dt.TorrentModel fromBytes(Uint8List bytes) {
    final model = dt.TorrentParser.parseBytes(bytes);
    _rejectUnsafePaths(model);
    final infoDict = TorrentFile.infoDictIn(bytes);
    // Хеш v2-раздачи считается иначе (sha256), и такие раздачи здесь ещё
    // не встречались — трогаем только то, о чём знаем наверняка.
    if (infoDict == null || model.version != dt.TorrentVersion.v1) return model;
    return dt.TorrentModel(
      name: TorrentFile.name(infoDict) ?? model.name,
      files: model.files,
      infoHashBuffer: Uint8List.fromList(sha1.convert(infoDict).bytes),
      pieceLength: model.pieceLength,
      pieces: model.pieces,
      announces: model.announces,
      nodes: model.nodes,
      length: model.length,
      version: model.version,
      metaVersion: model.metaVersion,
      fileTree: model.fileTree,
      pieceLayers: model.pieceLayers,
      rootHash: model.rootHash,
      infoDictBytes: infoDict,
      rawData: model.rawData,
    );
  }

  /// Отклоняет раздачу, которая писала бы мимо папки загрузки.
  ///
  /// Проверка наша, потому что больше ничья: разборщик склеивает сегменты
  /// пути как есть, движок складывает `папка + путь` конкатенацией, а
  /// симлинк создаёт с целью прямо из раздачи. Торрент приходит от
  /// незнакомых людей — это ровно тот случай, ради которого в `.evsave`
  /// проверяют zip-slip.
  ///
  /// Место выбрано одно на всё: и `.torrent` с диска, и метаданные
  /// magnet-ссылки проходят через [fromBytes], и мимо этой проверки в
  /// движок не попадает ничего.
  ///
  /// Смотреть приходится и в `files`, и в дерево v2 (`file tree`): у
  /// hybrid-раздачи они независимы, а раскладку движок строит по дереву,
  /// склеивая его ключи как есть. Безобидные `files` рядом с деревом
  /// `{"..": {"..": {"x.bat": …}}}` писали мимо папки игр.
  static void _rejectUnsafePaths(dt.TorrentModel model) {
    for (final file in model.files) {
      _rejectUnsafe(file.path, file.symlinkPath);
    }
    final tree = model.fileTree;
    if (tree == null) return;
    for (final file in dt.FileTreeHelper.extractFiles(tree, '')) {
      _rejectUnsafe(file.path, file.symlinkPath);
    }
  }

  static void _rejectUnsafe(String path, List<String>? link) {
    final unsafe = TorrentFile.unsafePath(path);
    if (unsafe != null) throw UnsafeTorrentException(unsafe);

    if (link == null || link.isEmpty) return;
    final target = TorrentFile.unsafePath(link.join('/'));
    if (target != null) throw UnsafeTorrentException(target);
  }
}
