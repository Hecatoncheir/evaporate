import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../../models/shelf.dart';
import 'toolbar.dart';

/// Панель полок над сеткой: сами полки со счётчиками, поиск и клавиши
/// «найти» и «добавить».
///
/// Счётчики считаются по найденному, а не по всей библиотеке: полка
/// показывает, сколько игр на ней осталось после поиска.
class LibraryShelfBar extends StatelessWidget {
  const LibraryShelfBar({
    super.key,
    required this.shelf,
    required this.found,
    required this.searchFocus,
    required this.onShelf,
    required this.onQuery,
    required this.onReturnToGames,
    required this.onScan,
    required this.onAdd,
  });

  final Shelf shelf;

  /// Игры, прошедшие поиск, — из них и считаются полки.
  final List<Game> found;

  final FocusNode searchFocus;
  final ValueChanged<Shelf> onShelf;
  final ValueChanged<String> onQuery;
  final VoidCallback onReturnToGames;
  final VoidCallback onScan;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LibraryToolbar(
      shelf: shelf,
      counts: {
        for (final value in Shelf.values)
          value: gamesOnShelf(found, value).length,
      },
      onShelf: onShelf,
      searchFocus: searchFocus,
      onReturnToGames: onReturnToGames,
      onQuery: onQuery,
      onScan: onScan,
      onAdd: onAdd,
    );
  }
}
