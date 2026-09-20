import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/game.dart';
import '../system/app_log.dart';
import 'image_size.dart';

/// Витрина игры в библиотеке Steam — четыре картинки, каждая под своим
/// именем в папке `grid`.
///
/// Одной вертикальной обложки мало: ею Steam рисует только сетку
/// библиотеки. Полка «недавних» берёт горизонтальную плашку, а страница
/// игры — широкий задник с названием поверх. Положив одну, получаешь игру,
/// которая в сетке выглядит как все, а на своей странице — как пустой лист.
class SteamArtwork {
  const SteamArtwork({this.portrait, this.capsule, this.hero, this.logo});

  /// `<appid>p.jpg` — вертикальная, 2:3, для сетки библиотеки.
  final List<int>? portrait;

  /// `<appid>.jpg` — горизонтальная плашка для полок и списков.
  final List<int>? capsule;

  /// `<appid>_hero.jpg` — широкий задник страницы игры.
  final List<int>? hero;

  /// `<appid>_logo.png` — название игры картинкой поверх задника.
  final List<int>? logo;

  bool get isEmpty =>
      portrait == null && capsule == null && hero == null && logo == null;
}

/// Витрина ярлыка: четыре картинки в папке `grid`.
///
/// Своим файлом, потому что живёт отдельной жизнью от списка ярлыков:
/// неудача здесь ярлыка не отменяет — игра без обложки это игра без
/// обложки, а отказ ради неё означал бы «не добавили вовсе».
class SteamGrid {
  const SteamGrid({AppLog Function()? log}) : log = log ?? _appLog;

  /// Куда писать о неудаче. Функцией — как `L Function()` у блоков.
  final AppLog Function() log;

  static AppLog _appLog() => AppLog.instance;

  /// Имя файла обложки в `grid`.
  ///
  /// Steam различает их по имени: вертикальная витрина библиотеки — это
  /// `<appid>p.jpg`, горизонтальная плашка — `<appid>.jpg`. Наша обложка
  /// бывает и той и другой: каталог сначала просит `library_600x900`, а
  /// если её не нарисовали, берёт горизонтальную `header`. Положить
  /// горизонтальную под именем вертикальной — значит растянуть её на
  /// 600×900, и выглядит это хуже, чем пустая рамка.
  static String nameFor(int appId, List<int> cover) {
    final size = imageSizeOf(cover);
    final portrait = size == null || size.height >= size.width;
    final id = appId.toUnsigned(32);
    return portrait ? '${id}p.jpg' : '$id.jpg';
  }

  /// Кладёт в `grid` всё, что для игры есть.
  Future<void> write(
    Game game, {
    required String gridDir,
    required int appId,
    required SteamArtwork? artwork,
  }) async {
    final files = _fromCatalog(appId, artwork);
    try {
      await _addOwnCover(game, appId, files);
      if (files.isEmpty) return;
      final dir = Directory(gridDir);
      await dir.create(recursive: true);
      for (final file in files.entries) {
        await File(p.join(dir.path, file.key))
            .writeAsBytes(file.value, flush: true);
      }
    } on FileSystemException catch (error) {
      // Витрина ярлыка не отменяет, но пустые обложки в Steam без следа в
      // журнале не объяснить.
      log().write('витрина ярлыка Steam не записана', error);
    }
  }

  /// Присланное каталогом — под именами, по которым Steam узнаёт роль.
  static Map<String, List<int>> _fromCatalog(int appId, SteamArtwork? artwork) {
    final id = appId.toUnsigned(32);
    return {
      '${id}p.jpg': ?artwork?.portrait,
      '$id.jpg': ?artwork?.capsule,
      '${id}_hero.jpg': ?artwork?.hero,
      '${id}_logo.png': ?artwork?.logo,
    };
  }

  /// Своей обложкой закрываем ту створку, которая осталась пустой:
  /// класть её поверх присланной каталогом незачем.
  Future<void> _addOwnCover(
    Game game,
    int appId,
    Map<String, List<int>> files,
  ) async {
    final cover = game.coverPath;
    if (cover == null || cover.isEmpty) return;
    final source = File(cover);
    if (!await source.exists()) return;
    final bytes = await source.readAsBytes();
    files.putIfAbsent(nameFor(appId, bytes), () => bytes);
  }
}
