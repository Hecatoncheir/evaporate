import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

/// Облик задаёт тема, а не виджет.
///
/// Разбросанные по виджетам числа расходятся сами собой — тот же довод,
/// которым в `motion.dart` обоснованы токены длительностей, — а ветвление
/// по схеме внутри виджета означает, что третья схема потребовала бы
/// правки каждого из них. Вне файлов темы не должно быть:
///
/// - `isDark` — различие схем записывается данными темы, а не кодом;
/// - `fontSize:` — кегль берётся из ролей типографики;
/// - `Duration(milliseconds:` — длительность берётся из `context.motion`;
/// - `BorderRadius.circular(<число>)` — радиус берётся из `EvaporateTheme`.
///
/// Списки ниже — известные нарушители на момент введения правила (этап 2
/// в `TODO.md`), с числом вхождений. Пополнять их нельзя; вынесенное —
/// вычёркивать или уменьшать число.
void main() {
  bool isThemeFile(String path) =>
      path.startsWith('lib/ui/theme/') || path == 'lib/ui/theme.dart';

  final sources = dartSources('lib/ui', skip: isThemeFile);

  Iterable<String> count(RegExp pattern) sync* {
    for (final file in sources) {
      final n = pattern.allMatches(file.code).length;
      if (n > 0) yield '${file.path}: $n';
    }
  }

  test('isDark не ветвит виджеты', () {
    expectRatchet(
      found: count(RegExp(r'\bisDark\b')),
      known: _isDark,
      rule: 'различие схем — поле темы компонента, а не ветвление в виджете',
    );
  });

  test('кегль не задаётся по месту', () {
    expectRatchet(
      found: count(RegExp(r'\bfontSize\s*:')),
      known: _fontSize,
      rule: 'кегль — роль типографики темы',
    );
  });

  test('длительности не задаются числом по месту', () {
    expectRatchet(
      found: count(RegExp(r'Duration\(\s*milliseconds\s*:')),
      known: _durations,
      rule: 'длительность — токен context.motion',
    );
  });

  test('радиусы не задаются числом по месту', () {
    expectRatchet(
      found: count(RegExp(r'BorderRadius\.circular\(\s*\d')),
      known: _radii,
      rule: 'радиус — токен EvaporateTheme',
    );
  });

  // Расширение, которое есть у одной схемы и нет у другой, молча отдаёт
  // виджету запасное значение, а плавная смена схемы смешивает его с
  // пустотой. Проверяем и сами схемы, и их смесь посередине перехода.
  test('у обеих схем один набор расширений, и он переживает смену', () {
    final dark = EvaporateTheme.dark();
    final light = EvaporateTheme.light();

    expect(dark.extensions.keys.toSet(), light.extensions.keys.toSet());
    final mixed = ThemeData.lerp(dark, light, 0.5);
    expect(mixed.extensions.keys.toSet(), dark.extensions.keys.toSet());
    for (final extension in mixed.extensions.values) {
      expect(
        extension.runtimeType,
        dark.extensions[extension.type]!.runtimeType,
      );
    }
  });
}

const _isDark = <String>[];

const _fontSize = [
  'lib/ui/downloads/available_games.dart: 2',
  'lib/ui/downloads/download_activity.dart: 4',
  'lib/ui/downloads/engine_status.dart: 2',
  'lib/ui/downloads/queue_column.dart: 6',
  'lib/ui/downloads/task_card.dart: 4',
  'lib/ui/library/add_game_dialog.dart: 4',
  'lib/ui/library/detail/action_panel.dart: 4',
  'lib/ui/library/detail/detail_cover.dart: 2',
  'lib/ui/library/detail/detail_header.dart: 3',
  'lib/ui/library/detail/files_section.dart: 2',
  'lib/ui/library/detail/rating_row.dart: 4',
  'lib/ui/library/drop_overlay.dart: 2',
  'lib/ui/library/featured_game.dart: 6',
  'lib/ui/library/game_cover.dart: 2',
  'lib/ui/library/saves/restore_dialog.dart: 9',
  'lib/ui/library/saves/rule_dialog.dart: 5',
  'lib/ui/library/saves/rule_tile.dart: 2',
  'lib/ui/library/saves/save_tag.dart: 1',
  'lib/ui/library/saves/snapshot_tile.dart: 2',
  'lib/ui/library/saves/suggestions_dialog.dart: 3',
  'lib/ui/library/saves/watched_folders.dart: 4',
  'lib/ui/library/saves_section.dart: 2',
  'lib/ui/library/scan_folder_dialog.dart: 8',
  'lib/ui/library/toolbar.dart: 2',
  'lib/ui/saves/bulk_transfer_card.dart: 4',
  'lib/ui/saves/snapshot_history.dart: 4',
  'lib/ui/saves/sync_folder_card.dart: 7',
  'lib/ui/settings/about_card.dart: 4',
  'lib/ui/settings/effects_card.dart: 4',
  'lib/ui/settings/gamepad_settings.dart: 9',
  'lib/ui/settings/log_card.dart: 3',
  'lib/ui/settings/notification_settings.dart: 4',
  'lib/ui/settings/path_setting.dart: 2',
  'lib/ui/settings/pickers.dart: 6',
  'lib/ui/settings/proxy_settings_card.dart: 8',
  'lib/ui/settings/settings_page.dart: 10',
  'lib/ui/settings/speed_field.dart: 2',
  'lib/ui/shell/app_footer.dart: 1',
  'lib/ui/shell/navigation.dart: 2',
  'lib/ui/shell/top_bar.dart: 1',
  'lib/ui/widgets/button_hints.dart: 2',
  'lib/ui/widgets/common.dart: 6',
  // Переехал из auto_snapshot_toggle.dart вместе с виджетом.
  'lib/ui/widgets/labeled_switch_row.dart: 1',
  'lib/ui/widgets/readout_panel.dart: 2',
  'lib/ui/widgets/section_heading.dart: 1',
];

const _durations = [
  'lib/ui/library/game_cover.dart: 1',
  'lib/ui/widgets/animated_progress.dart: 1',
  'lib/ui/widgets/fade_indexed_stack.dart: 1',
  'lib/ui/widgets/liquid_selection.dart: 1',
  'lib/ui/widgets/nav_tile.dart: 3',
  'lib/ui/widgets/rise_in.dart: 1',
];

const _radii = [
  'lib/ui/library/game_cover.dart: 1',
  'lib/ui/library/saves/save_tag.dart: 1',
  'lib/ui/widgets/button_hints.dart: 1',
];
