import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/guards.dart';

/// Слои зависят друг от друга в одну сторону: интерфейс знает блоки,
/// блоки — сервисы, сервисы — модели и ядро, и никогда наоборот.
///
/// Обратная зависимость незаметна, пока не понадобится проверить слой
/// отдельно: блок, тянущий `lib/ui`, не соберётся без Flutter-виджетов,
/// модель, тянущая сервис, — без его зависимостей. А `lib/models` и
/// `lib/core` — то, что читают на другом конце переноса сохранений и в
/// изоляте разбора базы путей: Flutter им не нужен вовсе.
///
/// Списки ниже — известные нарушители на момент введения правила (этапы 1
/// и 6 в `TODO.md`). Пополнять их нельзя; исправленное — вычёркивать.
void main() {
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

  Iterable<String> violations(
    List<String> layers,
    bool Function(String target) forbidden,
  ) sync* {
    for (final layer in layers) {
      for (final file in dartSources(layer)) {
        for (final target in importsOf(file)) {
          if (forbidden(target)) yield '${file.path} -> $target';
        }
      }
    }
  }

  test('блоки, сервисы, модели и ядро не знают интерфейса', () {
    expectRatchet(
      found: violations([
        'lib/bloc',
        'lib/services',
        'lib/models',
        'lib/core',
      ], (target) => target.startsWith('lib/ui/')),
      known: _intoUi,
      rule: 'нужное блокам — в нейтральное место, не в lib/ui',
    );
  });

  test('модели и ядро не знают Flutter, блоков и сервисов', () {
    expectRatchet(
      found: violations(
        ['lib/models', 'lib/core'],
        (target) =>
            target.startsWith('package:flutter/') ||
            target.startsWith('lib/bloc/') ||
            target.startsWith('lib/services/') ||
            target.startsWith('lib/input/'),
      ),
      known: _belowServices,
      rule: 'модели и ядро — чистый Dart без верхних слоёв',
    );
  });
}

const _intoUi = <String>[];

const _belowServices = [
  // Остаётся намеренно. Раскладка геймпада — настройка, и хранить её
  // больше негде; а перенести `GamepadBinding` в модели значило бы
  // притащить туда `package:gamepads` — плагин с платформенным кодом,
  // то есть ровно то, от чего этот слой и берегут.
  'lib/models/app_settings.dart -> lib/input/gamepad_binding.dart',
];
