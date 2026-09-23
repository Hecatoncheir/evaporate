import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EvaporateSpacing.vast),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset_outlined,
              size: EvaporateIconSize.hero,
              color: context.colors.accent,
            ),
            const SizedBox(height: EvaporateSpacing.panel),
            Text(
              libraryIsEmpty ? l.libraryEmpty : l.nothingFound,
              textAlign: TextAlign.center,
              style: context.text.title,
            ),
            if (libraryIsEmpty) ...[
              const SizedBox(height: EvaporateSpacing.gap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  l.libraryEmptyNote,
                  textAlign: TextAlign.center,
                  style: context.text.prose.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: EvaporateSpacing.section),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: EvaporateIconSize.panel),
                label: Text(l.addGame),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
