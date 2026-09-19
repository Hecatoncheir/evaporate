import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import '../support/widget_structure.dart';

/// Один файл — один публичный виджет; ни приватных виджетов, ни методов,
/// собирающих виджеты.
///
/// Приватный виджет и метод-виджет прячут часть экрана там, где её не
/// найти по имени, не переиспользовать и не проверить отдельно; метод к
/// тому же лишён своего `Element`: у него нет границы перестроения и
/// `const`, и в инспекторе его не видно. Законны `_FooState` — это идиома
/// Flutter, а не виджет, — и `build`.
///
/// Списки ниже — известные нарушители на момент введения правила (см.
/// этап 3 в `TODO.md`). Пополнять их нельзя; вынесенное — вычёркивать.
void main() {
  final sources = dartSources('lib/ui');

  test('новых приватных виджетов нет', () {
    expectRatchet(
      found: sources.expand(privateWidgets),
      known: _privateWidgets,
      rule: 'приватный виджет — в свой файл под публичным именем',
    );
  });

  test('новых методов, собирающих виджеты, нет', () {
    expectRatchet(
      found: sources.expand(widgetFunctions),
      known: _widgetFunctions,
      rule: 'метод-виджет — в класс виджета своим файлом',
    );
  });

  // Число после двоеточия — сколько виджетов в файле сейчас. Вынесли
  // один — число в списке уменьшается, вынесли все, кроме одного, —
  // запись уходит.
  test('новых файлов с несколькими виджетами нет', () {
    expectRatchet(
      found: sources.expand(crowdedFiles),
      known: _crowdedFiles,
      rule: 'один файл — один виджет',
    );
  });
}

const _privateWidgets = [
  'lib/ui/downloads/available_games.dart: _RemoveButton',
  'lib/ui/downloads/download_activity.dart: _Metric',
  'lib/ui/downloads/downloads_page.dart: _Heading',
  'lib/ui/library/add_game_dialog.dart: _AddGameDialog',
  'lib/ui/library/add_game_dialog.dart: _PathPicker',
  'lib/ui/library/detail/action_panel.dart: _SteamShortcutButton',
  'lib/ui/library/detail/action_panel.dart: _SteamLookupButton',
  'lib/ui/library/detail/rating_row.dart: _Count',
  'lib/ui/library/detail/rating_row.dart: _Metacritic',
  'lib/ui/library/featured_game.dart: _Art',
  'lib/ui/library/featured_game.dart: _CompactContent',
  'lib/ui/library/featured_game.dart: _Eyebrow',
  'lib/ui/library/featured_game.dart: _Actions',
  'lib/ui/library/featured_game.dart: _PlaytimeReadout',
  'lib/ui/library/foil_card.dart: _FoilScope',
  'lib/ui/library/game_cover.dart: _Art',
  'lib/ui/library/game_cover.dart: _TitlePlate',
  'lib/ui/library/game_cover.dart: _StatusBadge',
  'lib/ui/library/game_cover.dart: _ProgressStrip',
  'lib/ui/library/saves_section.dart: _FindPathsButton',
  'lib/ui/library/scan_folder_dialog.dart: _ScanFolderDialog',
  'lib/ui/library/scan_folder_dialog.dart: _Progress',
  'lib/ui/library/scan_folder_dialog.dart: _DropArea',
  'lib/ui/library/shots_backdrop.dart: _Slideshow',
  'lib/ui/library/shots_backdrop.dart: _Shot',
  'lib/ui/library/toolbar.dart: _AddGameButton',
  'lib/ui/saves/bulk_transfer_card.dart: _BulkReportView',
  'lib/ui/saves/saves_page.dart: _Heading',
  'lib/ui/saves/snapshot_history.dart: _SnapshotRow',
  'lib/ui/saves/sync_folder_card.dart: _PackageRow',
  'lib/ui/settings/gamepad_settings.dart: _BindingRow',
  'lib/ui/settings/gamepad_settings.dart: _CaptureButtonDialog',
  'lib/ui/settings/proxy_settings_card.dart: _Field',
  'lib/ui/settings/proxy_settings_card.dart: _Warning',
  'lib/ui/settings/proxy_settings_card.dart: _Note',
  'lib/ui/shell.dart: _Sections',
  'lib/ui/shell/navigation.dart: _QueueBadge',
  'lib/ui/shell/top_bar.dart: _WindowDragArea',
  'lib/ui/widgets/animated_progress.dart: _Hatching',
  'lib/ui/widgets/button_hints.dart: _HintChip',
  'lib/ui/widgets/liquid_selection.dart: _LiquidInkScope',
];

const _widgetFunctions = [
  'lib/ui/downloads/download_activity.dart: _metrics',
  'lib/ui/downloads/download_activity.dart: _amounts',
  'lib/ui/downloads/downloads_page.dart: _columns',
  'lib/ui/downloads/downloads_page.dart: _readout',
  'lib/ui/downloads/task_card.dart: _header',
  'lib/ui/downloads/task_card.dart: _actions',
  'lib/ui/downloads/task_card.dart: _stats',
  'lib/ui/library/add_game_dialog.dart: _kindPicker',
  'lib/ui/library/add_game_dialog.dart: _startNow',
  'lib/ui/library/add_game_dialog.dart: _buildSourceFields',
  'lib/ui/library/detail/action_panel.dart: _buildRow',
  'lib/ui/library/detail/action_panel.dart: _primaryActions',
  'lib/ui/library/featured_game.dart: _full',
  'lib/ui/library/game_cover.dart: _tile',
  'lib/ui/library/game_cover.dart: image',
  'lib/ui/library/game_detail.dart: _content',
  'lib/ui/library/game_detail.dart: _wrapHistory',
  'lib/ui/library/library_page.dart: _heading',
  'lib/ui/library/library_page.dart: _toolbar',
  'lib/ui/library/library_page.dart: _measuredGrid',
  'lib/ui/library/library_page.dart: _grid',
  'lib/ui/library/library_page.dart: _tile',
  'lib/ui/library/library_page.dart: _cover',
  'lib/ui/library/library_page.dart: _empty',
  'lib/ui/library/saves/restore_dialog.dart: _content',
  'lib/ui/library/saves/restore_dialog.dart: _localFreshness',
  'lib/ui/library/saves/restore_dialog.dart: _targetList',
  'lib/ui/library/saves/restore_dialog.dart: _options',
  'lib/ui/library/saves/restore_dialog.dart: _actions',
  'lib/ui/library/saves/rule_dialog.dart: _absoluteWarning',
  'lib/ui/library/saves/snapshot_tile.dart: _summary',
  'lib/ui/library/saves/snapshot_tile.dart: _action',
  'lib/ui/library/saves/watched_folders.dart: _hintRow',
  'lib/ui/library/saves/watched_folders.dart: _footer',
  'lib/ui/library/scan_folder_dialog.dart: _list',
  'lib/ui/library/toolbar.dart: _arrange',
  'lib/ui/library/toolbar.dart: _search',
  'lib/ui/saves/saves_page.dart: _readout',
  'lib/ui/saves/snapshot_history.dart: _summary',
  'lib/ui/settings/about_card.dart: _menuEntryRow',
  'lib/ui/settings/about_card.dart: _buttons',
  'lib/ui/settings/effects_card.dart: _presets',
  'lib/ui/settings/effects_card.dart: _details',
  'lib/ui/settings/gamepad_settings.dart: _status',
  'lib/ui/settings/gamepad_settings.dart: _deadzone',
  'lib/ui/settings/notification_settings.dart: _warning',
  'lib/ui/settings/notification_settings.dart: _buttons',
  'lib/ui/settings/proxy_settings_card.dart: _kindPicker',
  'lib/ui/settings/proxy_settings_card.dart: _addressFields',
  'lib/ui/settings/proxy_settings_card.dart: _applyRow',
  'lib/ui/settings/settings_page.dart: _appearanceCard',
  'lib/ui/settings/settings_page.dart: _windowCard',
  'lib/ui/settings/settings_page.dart: _downloadsCard',
  'lib/ui/settings/settings_page.dart: _metadataCard',
  'lib/ui/settings/settings_page.dart: _engineCard',
  'lib/ui/settings/settings_page.dart: _savesCard',
  'lib/ui/settings/settings_page.dart: _note',
  'lib/ui/shell.dart: _layout',
  'lib/ui/shell.dart: _panel',
  'lib/ui/shell.dart: _footer',
  'lib/ui/shell/navigation.dart: _rack',
  'lib/ui/shell/navigation.dart: _button',
  'lib/ui/shell/top_bar.dart: _brand',
  'lib/ui/shell/top_bar.dart: _actions',
  'lib/ui/shell/top_bar.dart: _windowActions',
  'lib/ui/widgets/ambient_light.dart: wash',
  'lib/ui/widgets/common.dart: _face',
  'lib/ui/widgets/readout_panel.dart: _withBars',
  'lib/ui/widgets/window_frame.dart: _resize',
];

const _crowdedFiles = [
  'lib/ui/downloads/available_games.dart: 4',
  'lib/ui/downloads/download_activity.dart: 4',
  'lib/ui/downloads/downloads_page.dart: 2',
  'lib/ui/downloads/engine_status.dart: 2',
  'lib/ui/downloads/queue_column.dart: 5',
  'lib/ui/library/add_game_dialog.dart: 2',
  'lib/ui/library/detail/action_panel.dart: 4',
  'lib/ui/library/detail/detail_cover.dart: 2',
  'lib/ui/library/detail/rating_row.dart: 3',
  'lib/ui/library/drop_overlay.dart: 2',
  'lib/ui/library/featured_game.dart: 6',
  'lib/ui/library/foil_card.dart: 3',
  'lib/ui/library/game_cover.dart: 5',
  'lib/ui/library/saves_section.dart: 3',
  'lib/ui/library/scan_folder_dialog.dart: 3',
  'lib/ui/library/shots_backdrop.dart: 3',
  'lib/ui/library/toolbar.dart: 4',
  'lib/ui/saves/bulk_transfer_card.dart: 2',
  'lib/ui/saves/saves_page.dart: 2',
  'lib/ui/saves/snapshot_history.dart: 2',
  'lib/ui/saves/sync_folder_card.dart: 2',
  'lib/ui/settings/gamepad_settings.dart: 3',
  'lib/ui/settings/pickers.dart: 3',
  'lib/ui/settings/proxy_settings_card.dart: 4',
  'lib/ui/shell.dart: 2',
  'lib/ui/shell/app_footer.dart: 2',
  'lib/ui/shell/navigation.dart: 2',
  'lib/ui/shell/top_bar.dart: 3',
  'lib/ui/widgets/animated_progress.dart: 2',
  'lib/ui/widgets/button_hints.dart: 2',
  'lib/ui/widgets/common.dart: 6',
  'lib/ui/widgets/liquid_selection.dart: 3',
  'lib/ui/widgets/readout_panel.dart: 2',
  'lib/ui/widgets/spatial_surface.dart: 3',
  'lib/ui/widgets/window_frame.dart: 2',
];
