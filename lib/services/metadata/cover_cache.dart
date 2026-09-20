import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/format.dart';

/// Кэш картинок библиотеки: обложки и кадры из игр.
///
/// Отдельно от блока, потому что это файловая работа со своими правилами,
/// а не состояние: **трогаем только свой кэш**. Обложку, выбранную
/// человеком самим, удалять нельзя — она лежит где угодно и принадлежит
/// ему, а не нам.
class CoverCache {
  const CoverCache({required this.coversDir, required this.shotsDir});

  final String coversDir;
  final String shotsDir;

  /// Наша ли это обложка. Пусто — значит, своей ещё нет, и места мы не
  /// занимаем: такую можно заменить.
  bool ownsCover(String? path) => path == null || p.isWithin(coversDir, path);

  /// Кладёт обложку и возвращает её путь.
  ///
  /// `null` — писать было нечего, не вышло или обложка чужая: из-за
  /// картинки не теряют ни `appid`, ни описание, ни поиск сейвов.
  Future<String?> writeCover(
    String gameId,
    List<int>? bytes, {
    String? current,
  }) async {
    if (bytes == null || !ownsCover(current)) return null;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      p.join(coversDir, '${safeFileName(gameId)}-$stamp-steam.jpg'),
    );
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on FileSystemException {
      await delete(file.path);
      return null;
    }
  }

  /// Кладёт кадры из игры и возвращает пути записанных.
  ///
  /// Неудача одного кадра подборку не отменяет: подложка — украшение, и
  /// терять из-за неё остальное не за что.
  Future<List<String>> writeShots(String gameId, List<List<int>> images) async {
    if (images.isEmpty) return const [];

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final written = <String>[];
    for (var index = 0; index < images.length; index++) {
      final file = File(
        p.join(shotsDir, '${safeFileName(gameId)}-$stamp-$index.jpg'),
      );
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(images[index], flush: true);
        written.add(file.path);
      } on FileSystemException {
        // Один не записавшийся кадр подборку не отменяет.
      }
    }
    return written;
  }

  /// Убирает свою обложку. Чужую не трогает.
  Future<void> deleteCover(String? path) async {
    if (path == null || !p.isWithin(coversDir, path)) return;
    await delete(path);
  }

  /// Убирает свои кадры: заменённые новой подборкой или осиротевшие, пока
  /// ходили в сеть.
  Future<void> deleteShots(Iterable<String> paths) async {
    for (final path in paths) {
      if (!p.isWithin(shotsDir, path)) continue;
      await delete(path);
    }
  }

  /// Убирает файл, который оказался не нужен.
  ///
  /// Ошибку гасит: лишний файл в кэше безвреден, а отменять из-за него
  /// найденные метаданные не за что.
  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Лишний файл в кэше безвреден.
    }
  }
}
