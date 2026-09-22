import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';

/// Пустая полка. Два случая, и путать их нельзя: в библиотеке нет ни одной
/// игры — или поиск ничего не нашёл. В первом человеку нужна клавиша
/// «добавить», во втором она только мешает.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    required this.libraryIsEmpty,
    required this.onAdd,
  });

  final bool libraryIsEmpty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!libraryIsEmpty) {
      return EmptyState(
        icon: Icons.videogame_asset_outlined,
        title: l.nothingFound,
      );
    }
    return EmptyState(
      icon: Icons.videogame_asset_outlined,
      title: l.libraryEmpty,
      description: l.libraryEmptyNote,
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: EvaporateIconSize.panel),
        label: Text(l.addGame),
      ),
    );
  }
}
