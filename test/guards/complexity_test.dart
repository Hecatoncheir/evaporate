import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_complexity.dart';
import '../support/guards.dart';

/// Функции остаются короткими, неглубокими и читаемыми с одного прохода.
///
/// Пороги — сложность 15, длина 60 строк, вложенность 3. Их, как и порог
/// покрытия, держат следом за достигнутым: убрали тяжёлые функции —
/// порог опускают, иначе он перестаёт ловить хоть что-то.
///
/// Списки ниже — известные нарушители со своим числом на момент введения
/// правила (этап 5 в `TODO.md`). Выросло число — это новое нарушение;
/// уменьшилось — число в списке правят вслед; опустилось до порога —
/// запись вычёркивают.
const maxComplexity = 15;
const maxLines = 60;
const maxNesting = 3;

void main() {
  final functions = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        if (entity.path.replaceAll(r'\', '/') case final path
            when !isGenerated(path))
          ...measure(path, entity.readAsStringSync()),
  ];

  Iterable<String> over(int Function(FunctionMetrics) metric, int limit) sync* {
    for (final f in functions) {
      final value = metric(f);
      if (value > limit) yield '${f.path}: ${f.name}: $value';
    }
  }

  group('ворота', () {
    test('сложность функций не выше $maxComplexity', () {
      expectRatchet(
        found: over((f) => f.complexity, maxComplexity),
        known: _complexity,
        rule: 'разложите ветвления: ранний выход, таблица, именованные шаги',
      );
    });

    test('функции не длиннее $maxLines строк', () {
      expectRatchet(
        found: over((f) => f.lines, maxLines),
        known: _lines,
        rule: 'длинную функцию — на шаги, длинный build — на виджеты',
      );
    });

    test('вложенность не глубже $maxNesting', () {
      expectRatchet(
        found: over((f) => f.nesting, maxNesting),
        known: _nesting,
        rule: 'глубокую вложенность — ранним выходом или своей функцией',
      );
    });
  });

  // Замер грубый, но обязан быть предсказуемым: иначе храповик роняет
  // прогон на ровном месте или молчит там, где стоило бы сказать.
  group('замер', () {
    FunctionMetrics only(String source) => measure('x.dart', source).single;

    test('ветвление глубже весит больше', () {
      final flat = only('void f(bool a, bool b) { if (a) {} if (b) {} }');
      final nested = only('void f(bool a, bool b) { if (a) { if (b) {} } }');

      expect(flat.complexity, 2);
      expect(nested.complexity, 3);
      expect(nested.nesting, 2);
    });

    test('смена логического оператора стоит единицу, повтор — нет', () {
      expect(only('bool f(a, b, c) => a && b && c;').complexity, 1);
      expect(only('bool f(a, b, c) => a && b || c;').complexity, 2);
    });

    test('слова в строках и комментариях не считаются', () {
      final f = only('''
String f() {
  // if (x) { while (y) {} }
  return 'if else for while && ||';
}
''');
      expect(f.complexity, 0);
    });

    test('замыкание засчитывается той функции, где объявлено', () {
      final all = measure('x.dart', '''
class A {
  void run(List<int> xs) {
    xs.forEach((x) {
      if (x > 0) {}
    });
  }
}
''');
      expect(all.map((f) => f.name), ['A.run']);
      expect(all.single.complexity, 2);
    });

    test('методы называются вместе с классом, а стрелки считаются', () {
      final all = measure('x.dart', '''
class A {
  int get size => 1;
  Widget build(BuildContext context) => const SizedBox();
}
int top(int x) => x > 0 ? x : -x;
''');
      expect(all.map((f) => f.name), ['A.size', 'A.build', 'top']);
      expect(all.last.complexity, 1);
    });
  });
}

const _complexity = [
  'lib/bloc/library/library_metadata.dart: _LibraryMetadata._onSavePathsLookup: 18',
  'lib/services/launch/game_launcher.dart: GameLauncher._start: 17',
  'lib/services/saves/save_activity_watch.dart: SaveActivityWatch._touchedFiles: 18',
];

const _lines = [
  'lib/bloc/downloads/downloads_bloc.dart: DownloadsBloc._finalize: 67',
  'lib/bloc/library/library_metadata.dart: _LibraryMetadata._onSavePathsLookup: 73',
  'lib/input/input_scope.dart: _InputScopeState.build: 64',
  'lib/main.dart: main: 103',
  'lib/models/app_settings.dart: AppSettings.copyWith: 73',
  'lib/models/game.dart: Game.copyWith: 63',
  'lib/services/launch/game_launcher.dart: GameLauncher._start: 68',
  'lib/services/saves/save_manager.dart: SaveManager._createSnapshot: 74',
  'lib/services/saves/save_manager.dart: SaveManager._restoreFrom: 65',
  'lib/ui/downloads/download_chart.dart: _SpeedChartPainter.paint: 65',
  'lib/ui/library/featured/featured_art.dart: FeaturedArt.build: 76',
  'lib/ui/saves/sync_folder_card.dart: SyncFolderCard.build: 63',
  'lib/ui/settings/effect_details.dart: EffectDetails._effects: 92',
  'lib/ui/widgets/liquid/liquid_selection_path.dart: liquidSelectionPath: 71',
  'lib/ui/widgets/window_chrome.dart: WindowChrome.resizeZones: 84',
];

/// Пусто, и пополнять нечем: вложенность глубже трёх лечится ранним
/// выходом или своей функцией — это всегда дешевле, чем запись здесь.
const _nesting = <String>[];
