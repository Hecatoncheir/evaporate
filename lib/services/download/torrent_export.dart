import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/game.dart';

/// Откуда взять `.torrent` игры, чтобы отдать его человеку.
///
/// Файл может лежать в трёх местах, и все три настоящие: копия, снятая при
/// добавлении торрента; файл, собранный движком из метаданных magnet-ссылки;
/// и, наконец, тот самый файл, который пользователь когда-то выбрал сам.
/// Порядок именно такой — от нашего к чужому: последний живёт вне
/// приложения и мог давно уехать вместе с папкой «Загрузки».
class TorrentExport {
  const TorrentExport({required this.torrentsDir, required this.enginePath});

  /// Где лежат копии `.torrent`, снятые при старте загрузки.
  final String torrentsDir;

  /// Что об этой раздаче знает движок. Идентификатор задачи живёт только до
  /// перезапуска, поэтому спрашиваем и по нему, и по infohash.
  final String? Function(String id) enginePath;

  /// Путь к файлу раздачи или `null`, если его нет ни у нас, ни у движка.
  Future<String?> locate(Game game) async {
    final stored = p.join(torrentsDir, '${game.id}.torrent');
    if (await File(stored).exists()) return stored;

    for (final id in [game.downloadTaskId, game.infoHash]) {
      if (id == null || id.isEmpty) continue;
      final path = enginePath(id);
      if (path != null && await File(path).exists()) return path;
    }

    final source = game.source;
    if (source != null &&
        source.kind == GameSourceKind.torrentFile &&
        await File(source.value).exists()) {
      return source.value;
    }
    return null;
  }

  /// Раздача ли это. Для локальной папки экспортировать нечего и предлагать
  /// нечего — кнопки в карточке такой игры быть не должно.
  static bool isTorrent(Game game) {
    final kind = game.source?.kind;
    return kind == GameSourceKind.magnet || kind == GameSourceKind.torrentFile;
  }
}
