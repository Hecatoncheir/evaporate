import 'package:flutter/material.dart';

import '../../models/shelf.dart';
import '../theme.dart';
import '../widgets/glass_surface.dart';
import 'toolbar/add_game_menu_button.dart';
import 'toolbar/library_search_field.dart';
import 'toolbar/shelf_tabs.dart';
import 'toolbar/toolbar_layout.dart';

/// Верхняя строка: полки с числами, поиск и добавление.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.shelf,
    required this.counts,
    required this.onShelf,
    required this.searchFocus,
    required this.onQuery,
    required this.onScan,
    required this.onAdd,
    required this.onReturnToGames,
  });

  final Shelf shelf;
  final Map<Shelf, int> counts;
  final ValueChanged<Shelf> onShelf;
  final FocusNode searchFocus;
  final ValueChanged<String> onQuery;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) {
    final filters = KeyedSubtree(
      key: const ValueKey('library-filter-group'),
      child: ShelfTabs(shelf: shelf, counts: counts, onShelf: onShelf),
    );
    final actions = KeyedSubtree(
      key: const ValueKey('library-actions-group'),
      child: AddGameMenuButton(onAdd: onAdd, onScan: onScan),
    );
    final search = LibrarySearchField(
      focusNode: searchFocus,
      onQuery: onQuery,
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
