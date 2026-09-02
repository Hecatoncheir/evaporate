import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/game.dart';
import 'executable_finder.dart';

/// Чем оказалось сброшенное в окно.
enum DropKind {
  /// Файл раздачи: заводим игру и ставим её в очередь загрузки.
  torrent,

  /// Готовая папка: игра уже на диске, её остаётся зарегистрировать.
  folder,

  /// Ни то ни другое — молча не проглатываем, а говорим об этом.
  unsupported,
}

/// Разобранный сброс: что это, как назвать и что запускать.
class DropCandidate {
  const DropCandidate({
    required this.path,
    required this.kind,
    required this.title,
    this.executablePath,
  });

  final String path;
  final DropKind kind;

  /// Предложенное название. Другого источника, кроме имени файла или папки,
  /// у сброса нет: диалога, где его вписывают руками, здесь не будет.
  final String title;

  /// Что запускать — только для папки, и только если нашлось.
  final String? executablePath;

  GameSource get source => GameSource(
    kind: kind == DropKind.torrent
        ? GameSourceKind.torrentFile
        : GameSourceKind.localFolder,
    value: path,
  );
}

/// Разбор того, что перетащили в окно библиотеки.
///
/// Отдельно от виджета: решение «это раздача, а это папка» проверяется на
/// настоящих файлах, без окна и без блоков. Magnet-ссылки сюда не попадают —
/// системы отдают их не как файл, и до приложения они не доезжают; их
/// по-прежнему вставляют в «Добавить игру».
class DropImport {
  const DropImport._();

  /// Разбирает сброшенные пути, сохраняя порядок: пользователь тащил их
  /// в каком-то своём, и перемешивать его незачем.
  static Future<List<DropCandidate>> inspect(Iterable<String> paths) async {
    final result = <DropCandidate>[];
    for (final path in paths) {
      result.add(await _inspectOne(path));
    }
    return result;
  }

  static Future<DropCandidate> _inspectOne(String path) async {
    if (await Directory(path).exists()) {
      // Исполняемый файл ищем сразу: без него игра добавится «установленной»,
      // но не запустится, и человеку пришлось бы искать его руками.
      final candidates = await ExecutableFinder.scan(path);
      return DropCandidate(
        path: path,
        kind: DropKind.folder,
        title: p.basename(path),
        executablePath: candidates.isEmpty ? null : candidates.first.path,
      );
    }

    if (await File(path).exists() && _isTorrent(path)) {
      return DropCandidate(
        path: path,
        kind: DropKind.torrent,
        title: p.basenameWithoutExtension(path),
      );
    }

    return DropCandidate(
      path: path,
      kind: DropKind.unsupported,
      title: p.basename(path),
    );
  }

  /// Расширение — единственный признак, доступный до чтения файла. Читать
  /// его здесь незачем: движок всё равно разберёт раздачу сам и сообщит,
  /// если она битая.
  static bool _isTorrent(String path) =>
      p.extension(path).toLowerCase() == '.torrent';
}
