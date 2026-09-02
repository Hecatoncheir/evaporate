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

    final segments = p.split(root);
    if (segments.isEmpty) return const [];

    var found = <String>[segments.first];
    for (final segment in segments.skip(1)) {
      if (!segment.contains('*')) {
        found = [for (final base in found) p.join(base, segment)];
        continue;
      }
      final pattern = _toRegExp(segment);
      final next = <String>[];
      for (final base in found) {
        final dir = Directory(base);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (pattern.hasMatch(name)) next.add(entity.path);
        }
      }
      found = next;
      if (found.isEmpty) return const [];
    }

    final templates = <String>[];
    for (final path in found) {
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
