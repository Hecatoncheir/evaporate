import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/save_path_template.dart';

/// Раскрытие масок в шаблонах путей.
///
/// База путей пишет «любой профиль» маской: `{APPDATA}/Игра/*/saves`.
/// Хранить такой шаблон в профиле нельзя — он должен указывать в одно
/// определённое место, иначе снимок неизвестно что заберёт. Поэтому маска
/// раскрывается здесь, по тому, что реально лежит на диске, и в правило
/// попадают уже конкретные пути.
///
/// Раскрывать приходится на живой файловой системе, а значит на каждом
/// устройстве заново — ради этого шаг и вынесен отдельно от разбора базы.
class SavePathGlobs {
  const SavePathGlobs._();

  /// Разворачивает шаблон в набор шаблонов без масок.
  ///
  /// Без масок возвращает его же — вызывающему не нужно проверять заранее.
  /// Если маска не совпала ни с чем, список пуст: такого пути на этой
  /// машине просто нет.
  static Future<List<String>> expand(String template, {String? gameDir}) async {
    if (!template.contains('*')) return [template];

    final root = SavePathTemplate.expand(template, gameDir: gameDir);
    // Плейсхолдер не подставился — разворачивать нечего.
    if (root.contains('{')) return const [];

    final paths = await _matchingPaths(p.split(root));
    return _collapseAll(paths, gameDir);
  }

  /// Идёт по частям пути слева направо и на каждой маске смотрит, что
  /// реально лежит на диске.
  ///
  /// Список растёт вширь: одна маска превращает один путь в столько, сколько
  /// нашлось подходящих папок. Не совпало ничего — дальше идти незачем.
  static Future<List<String>> _matchingPaths(List<String> segments) async {
    if (segments.isEmpty) return const [];

    var found = <String>[segments.first];
    for (final segment in segments.skip(1)) {
      if (!segment.contains('*')) {
        found = [for (final base in found) p.join(base, segment)];
        continue;
      }
      found = await _childrenMatching(found, _toRegExp(segment));
      if (found.isEmpty) return const [];
    }
    return found;
  }

  /// Содержимое папок [bases], чьё имя подошло под маску.
  static Future<List<String>> _childrenMatching(
    List<String> bases,
    RegExp pattern,
  ) async {
    final next = <String>[];
    for (final base in bases) {
      final dir = Directory(base);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (pattern.hasMatch(p.basename(entity.path))) next.add(entity.path);
      }
    }
    return next;
  }

  /// Свёртывает найденные пути обратно в шаблоны, отбрасывая повторы и то,
  /// чего на диске уже нет.
  static Future<List<String>> _collapseAll(
    List<String> paths,
    String? gameDir,
  ) async {
    final templates = <String>[];
    for (final path in paths) {
      if (!await _exists(path)) continue;
      final collapsed = SavePathTemplate.collapse(path, gameDir: gameDir);
      if (!templates.contains(collapsed)) templates.add(collapsed);
    }
    return templates;
  }

  static Future<bool> _exists(String path) async =>
      await Directory(path).exists() || await File(path).exists();

  /// `Save*` -> `^Save.*$`. Экранируем всё остальное: в названиях папок
  /// попадаются точки и скобки, и без экранирования они стали бы частью
  /// выражения.
  static RegExp _toRegExp(String segment) {
    final body = segment.split('*').map(RegExp.escape).join('.*');
    // Регистр не учитываем: на Windows и macOS файловая система его тоже
    // обычно не различает, а на Linux лишнее совпадение безобиднее пропуска.
    return RegExp('^$body\$', caseSensitive: false);
  }
}
