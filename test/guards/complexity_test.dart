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
  'lib/bloc/library/library_metadata.dart: _LibraryMetadata._onSteamLookup: 29',
  'lib/services/launch/game_launcher.dart: GameLauncher._start: 17',
  'lib/services/launch/steam_shortcuts.dart: SteamShortcuts._mostRecentAccount: 16',
  'lib/services/launch/vdf.dart: Vdf._tokens: 16',
  'lib/services/launch/vdf.dart: Vdf.parse: 19',
  'lib/services/saves/bulk_transfer.dart: BulkTransfer.importAll: 24',
  'lib/services/saves/restore_transaction.dart: _RestoreTransaction._buildRestorePlan: 25',
  'lib/services/saves/save_activity_watch.dart: SaveActivityWatch._touchedFiles: 18',
  'lib/ui/library/add_game_dialog.dart: _AddGameDialogState._buildRequest: 17',
  'lib/ui/settings/about_card.dart: _AboutCardState._install: 16',
  'lib/ui/widgets/game_drop_target.dart: _GameDropTargetState._handleDrop: 18',
];

const _lines = [
  'lib/bloc/downloads/downloads_bloc.dart: DownloadsBloc._finalize: 69',
  'lib/bloc/library/library_metadata.dart: _LibraryMetadata._onSavePathsLookup: 73',
  'lib/bloc/library/library_metadata.dart: _LibraryMetadata._onSteamLookup: 94',
  'lib/input/input_scope.dart: _InputScopeState.build: 64',
  'lib/main.dart: main: 105',
  'lib/models/app_settings.dart: AppSettings.copyWith: 73',
  'lib/models/game.dart: Game.copyWith: 63',
  'lib/services/launch/game_launcher.dart: GameLauncher._start: 68',
  'lib/services/saves/bulk_transfer.dart: BulkTransfer.exportAll: 66',
  'lib/services/saves/bulk_transfer.dart: BulkTransfer.importAll: 106',
  'lib/services/saves/restore_transaction.dart: _RestoreTransaction._buildRestorePlan: 61',
  'lib/services/saves/save_manager.dart: SaveManager._createSnapshot: 74',
  'lib/services/saves/save_manager.dart: SaveManager._restoreFrom: 72',
  'lib/ui/downloads/download_activity.dart: _SpeedChartPainter.paint: 65',
  'lib/ui/downloads/downloads_page.dart: DownloadsPage.build: 69',
  'lib/ui/library/detail/action_panel.dart: ActionPanel._primaryActions: 77',
  'lib/ui/library/detail/info_section.dart: InfoSection.build: 67',
  'lib/ui/library/featured_game.dart: _Art.build: 76',
  'lib/ui/library/game_cover.dart: GameCoverTile._tile: 70',
  'lib/ui/library/library_page.dart: _LibraryPageState._tile: 70',
  'lib/ui/library/library_page.dart: _LibraryPageState.build: 77',
  'lib/ui/library/portal_sparks.dart: PortalSparkField.edgeAt: 68',
  'lib/ui/library/saves/rule_dialog.dart: _RuleDialogState.build: 87',
  'lib/ui/library/saves/rule_tile.dart: RuleTile.build: 82',
  'lib/ui/saves/bulk_transfer_card.dart: _BulkReportView.build: 71',
  'lib/ui/saves/sync_folder_card.dart: SyncFolderCard.build: 84',
  'lib/ui/saves/sync_folder_card.dart: _PackageRow._pickGame: 61',
  'lib/ui/settings/effects_card.dart: LibraryEffectsCard._effects: 92',
  'lib/ui/settings/log_card.dart: _LogCardState.build: 83',
  'lib/ui/settings/settings_page.dart: SettingsPage._downloadsCard: 80',
  'lib/ui/settings/settings_page.dart: SettingsPage._savesCard: 62',
  'lib/ui/settings/settings_page.dart: SettingsPage.build: 68',
  'lib/ui/shell.dart: AppShell.build: 66',
  'lib/ui/widgets/liquid_selection.dart: liquidSelectionPath: 71',
  'lib/ui/widgets/window_frame.dart: WindowChrome.resizeZones: 84',
];

const _nesting = [
  'lib/services/metadata/steam_catalog.dart: SteamCatalog.imageBytes: 4',
  'lib/ui/settings/about_card.dart: _AboutCardState._install: 4',
];
