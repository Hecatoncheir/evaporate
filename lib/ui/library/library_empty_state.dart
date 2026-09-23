import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'add_game_dialog.dart';

/// Пустая полка. Два случая, и путать их нельзя: в библиотеке нет ни одной
/// игры — или поиск ничего не нашёл. В первом человеку нужна клавиша
/// «добавить», во втором она только мешает.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final libraryIsEmpty = context.select<LibraryBloc, bool>(
      (b) => b.state.games.isEmpty,
    );
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
                onPressed: () => showAddGameDialog(context),
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
