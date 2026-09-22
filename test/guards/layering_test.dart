import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import '../support/layering.dart';

/// Слои зависят друг от друга в одну сторону: интерфейс знает блоки,
/// блоки — сервисы, сервисы — модели и ядро, и никогда наоборот.
///
/// Обратная зависимость незаметна, пока не понадобится проверить слой
/// отдельно: блок, тянущий `lib/ui`, не соберётся без Flutter-виджетов,
/// модель, тянущая сервис, — без его зависимостей. А `lib/models` и
/// `lib/core` — то, что читают на другом конце переноса сохранений и в
/// изоляте разбора базы путей: Flutter им не нужен вовсе.
///
/// Проверка транзитивная: запретное, до которого слой дотягивается через
/// свои же импорты, — такое же нарушение, как прямое.
///
/// Списки ниже — известные нарушители на момент введения правила (этапы 1
/// и 6 в `TODO.md`). Пополнять их нельзя; исправленное — вычёркивать.
void main() {
  final graph = importGraph(dartSources('lib'));

  test('блоки, сервисы, модели и ядро не знают интерфейса', () {
    expectRatchet(
      found: layerViolations(graph, [
        'lib/bloc',
        'lib/services',
        'lib/models',
        'lib/core',
      ], (target) => target.startsWith('lib/ui/')),
      known: _intoUi,
      rule: 'нужное блокам — в нейтральное место, не в lib/ui',
    );
  });

  // Заявлено было давно, а проверялось только «сервисы не знают
  // интерфейса». Сервис, знающий блок, не проверить без блока — а блоки
  // ради сервисов и заводят.
  test('сервисы не знают блоков', () {
    expectRatchet(
      found: layerViolations(graph, [
        'lib/services',
      ], (target) => target.startsWith('lib/bloc/')),
      known: const [],
      rule: 'сервис отдаёт результат, а блок решает, что с ним делать',
    );
  });

  test('модели и ядро не знают Flutter, плагинов, блоков и сервисов', () {
    expectRatchet(
      found: layerViolations(
        graph,
        ['lib/models', 'lib/core'],
        (target) =>
            target.startsWith('lib/bloc/') ||
            target.startsWith('lib/services/') ||
            target.startsWith('lib/input/') ||
            (target.startsWith('package:') && !_pureDart(target)),
      ),
      known: _belowServices,
      rule: 'модели и ядро — чистый Dart без верхних слоёв',
    );
  });

  // Сломанная проверка — вечная зелень: страж, который ничего не
  // находит, выглядит ровно как страж, которому нечего найти.
  group('страж ловит нарушение', () {
    final graph = importGraph([
      SourceFile(
        'lib/models/a.dart',
        "import '../input/b.dart';\nimport 'package:equatable/equatable.dart';",
      ),
      SourceFile(
        'lib/input/b.dart',
        "import 'package:gamepads/gamepads.dart';",
      ),
      SourceFile('lib/services/s.dart', "import '../bloc/x/x_bloc.dart';"),
      SourceFile('lib/bloc/x/x_bloc.dart', ''),
    ]);
    bool plugin(String t) => t.startsWith('package:') && !_pureDart(t);

    test('прямой импорт', () {
      expect(
        layerViolations(graph, [
          'lib/services',
        ], (t) => t.startsWith('lib/bloc/')),
        ['lib/services/s.dart -> lib/bloc/x/x_bloc.dart'],
      );
    });

    test('транзитивный — через свой импорт', () {
      const expected =
          'lib/models/a.dart -> package:gamepads/gamepads.dart '
          '(через lib/input/b.dart)';
      expect(layerViolations(graph, ['lib/models'], plugin), [expected]);
    });

    test('чистый пакет не нарушение', () {
      expect(_pureDart('package:equatable/equatable.dart'), isTrue);
      expect(_pureDart('package:path_provider/path_provider.dart'), isFalse);
    });
  });
}

/// Пакеты, которые можно тянуть в модели и ядро: чистый Dart, без
/// платформенного кода и без Flutter. Список, а не запрет плагинов по
/// одному: новый плагин иначе прошёл бы, пока его не назовут поимённо.
bool _pureDart(String uri) =>
    const {
      'dart',
      'equatable',
      'path',
      'crypto',
      'uuid',
      'collection',
      'meta',
    }.contains(
      uri.startsWith('dart:') ? 'dart' : uri.split(':').last.split('/').first,
    );

const _intoUi = <String>[];

const _belowServices = [
  // Раскладка геймпада — настройка, и хранить её больше негде. Плагин
  // `package:gamepads` приходит в модели именно этой дорогой: раскладка
  // записана его `GamepadButton`. Чтобы убрать запись, нужна своя
  // перечислимая кнопок в моделях и перевод на границе ввода.
  'lib/models/app_settings.dart -> lib/input/gamepad_binding.dart',
  // Где лежат папки приложения и «Документы», знает только система, а
  // спросить её можно лишь плагином. Прочее ядро это не заражает: тем,
  // кому система недоступна, — тестам и изоляту разбора базы путей, —
  // каталоги задаются напрямую (`AppPaths.custom`).
  'lib/core/app_paths.dart -> package:path_provider/path_provider.dart',
  'lib/core/system_folders.dart -> package:path_provider/path_provider.dart',
];
