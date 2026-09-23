import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/glass_surface.dart';
import 'toolbar/add_game_menu_button.dart';
import 'toolbar/library_search_field.dart';
import 'toolbar/shelf_tabs.dart';
import 'toolbar/toolbar_layout.dart';

/// Верхняя строка: полки с числами, поиск и добавление.
///
/// Полку и запрос читают и меняют сами вкладки и поле поиска — через
/// `LibraryViewBloc`, числа у полок вкладки считают там же. Прежде над
/// этой строкой стояла `LibraryShelfBar`, которая только считала числа и
/// передавала семь параметров из восьми дальше.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.searchFocus,
    required this.onScan,
    required this.onReturnToGames,
  });

  final FocusNode searchFocus;
  final VoidCallback onScan;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) {
    const filters = KeyedSubtree(
      key: ValueKey('library-filter-group'),
      child: ShelfTabs(),
    );
    final actions = KeyedSubtree(
      key: const ValueKey('library-actions-group'),
      child: AddGameMenuButton(onScan: onScan),
    );
    final search = LibrarySearchField(
      focusNode: searchFocus,
      onReturnToGames: onReturnToGames,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EvaporateSpacing.card,
        EvaporateSpacing.panel,
        EvaporateSpacing.card,
        EvaporateSpacing.line,
      ),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: HardwareSurfaceTheme.of(context).toolbarOpacity,
        shadow: false,
        padding: const EdgeInsets.symmetric(
          horizontal: EvaporateSpacing.block,
          vertical: EvaporateSpacing.cluster,
        ),
        child: ToolbarLayout(
          filters: filters,
          actions: actions,
          search: search,
        ),
      ),
    );
  }
}
