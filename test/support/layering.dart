import 'package:path/path.dart' as p;

import 'guards.dart';

/// Импорты файла путями от корня репозитория: `lib/ui/labels.dart`, а
/// для чужих пакетов — как написано, `package:flutter/material.dart`.
Iterable<String> importsOf(SourceFile file) sync* {
  final directive = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final match in directive.allMatches(file.text)) {
    final uri = match.group(1)!;
    if (uri.startsWith('package:evaporate/')) {
      yield 'lib/${uri.substring('package:evaporate/'.length)}';
    } else if (uri.contains(':')) {
      yield uri;
    } else {
      yield p.posix.normalize(p.posix.join(p.posix.dirname(file.path), uri));
    }
  }
}

/// Граф импортов: файл → что он импортирует.
Map<String, List<String>> importGraph(Iterable<SourceFile> files) => {
  for (final file in files) file.path: importsOf(file).toList(),
};

/// Нарушения слоя: файл из [layers] дотягивается до запретного — сам или
/// через свои импорты.
///
/// Транзитивно, а не по прямым импортам: модель, импортирующая ввод,
/// который импортирует плагин, тянет плагин точно так же, как если бы
/// импортировала его сама. Прямой проверкой это не видно — так в
/// моделях и оказался `package:gamepads`. Запись — `файл -> запретное`,
/// а если дорога не прямая, то и через что: `(через lib/…)`.
Iterable<String> layerViolations(
  Map<String, List<String>> graph,
  List<String> layers,
  bool Function(String target) forbidden,
) sync* {
  for (final file in graph.keys) {
    if (!layers.any((layer) => file.startsWith('$layer/'))) continue;
    // Первый шаг от [file], которым до файла дошли: по нему и видно, какой
    // свой импорт тянет запретное.
    final firstHop = <String, String>{};
    final queue = [file];
    final seen = {file};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final target in graph[current] ?? const <String>[]) {
        if (!seen.add(target)) continue;
        final hop = firstHop[target] = current == file
            ? target
            : firstHop[current]!;
        if (forbidden(target)) {
          yield hop == target
              ? '$file -> $target'
              : '$file -> $target (через $hop)';
        } else if (graph.containsKey(target)) {
          queue.add(target);
        }
      }
    }
  }
}
