import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../../models/shelf.dart';
import '../theme.dart';
import '../widgets/glass_surface.dart';
import 'toolbar/add_game_menu_button.dart';
import 'toolbar/library_search_field.dart';
import 'toolbar/shelf_tabs.dart';
import 'toolbar/toolbar_layout.dart';

/// Верхняя строка: полки с числами, поиск и добавление.
///
/// Счётчики считаются по найденному, а не по всей библиотеке: полка
/// показывает, сколько игр на ней осталось после поиска. Полку и запрос
/// читают и меняют сами вкладки и поле поиска — через `LibraryViewBloc`.
/// Прежде над этой строкой стояла `LibraryShelfBar`, которая только
/// считала числа и передавала семь параметров из восьми дальше.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.found,
    required this.searchFocus,
    required this.onScan,
    required this.onAdd,
    required this.onReturnToGames,
  });

  /// Игры, прошедшие поиск, — из них и считаются полки.
  final List<Game> found;

  final FocusNode searchFocus;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) {
    final filters = KeyedSubtree(
      key: const ValueKey('library-filter-group'),
      child: ShelfTabs(
        counts: {
          for (final value in Shelf.values)
            value: gamesOnShelf(found, value).length,
        },
      ),
    );
    final actions = KeyedSubtree(
      key: const ValueKey('library-actions-group'),
      child: AddGameMenuButton(onAdd: onAdd, onScan: onScan),
    );
    final search = LibrarySearchField(
      focusNode: searchFocus,
      onReturnToGames: onReturnToGames,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: HardwareSurfaceTheme.of(context).toolbarOpacity,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ToolbarLayout(
          filters: filters,
          actions: actions,
          search: search,
        ),
      ),
    );
  }
}
