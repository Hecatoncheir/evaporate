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
  'lib/ui/library/add_game_dialog.dart: _AddGameDialog',
  'lib/ui/library/foil_card.dart: _FoilScope',
  'lib/ui/library/scan_folder_dialog.dart: _ScanFolderDialog',
  'lib/ui/widgets/liquid_selection.dart: _LiquidInkScope',
];

const _widgetFunctions = [
  'lib/ui/library/cover/cover_art.dart: image',
  'lib/ui/settings/about_card.dart: _menuEntryRow',
  'lib/ui/settings/about_card.dart: _buttons',
  'lib/ui/widgets/launcher_action_button.dart: _face',
];

const _crowdedFiles = [
  'lib/ui/library/detail/detail_cover.dart: 2',
  'lib/ui/library/drop_overlay.dart: 2',
  'lib/ui/library/foil_card.dart: 3',
  'lib/ui/widgets/liquid_selection.dart: 3',
  'lib/ui/widgets/spatial_surface.dart: 3',
];
