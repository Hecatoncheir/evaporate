import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/shelf.dart';
import '../../library/add_game_dialog.dart';
import '../design/theme.dart';
import '../first_run/ev_first_run_widgets.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';

/// Пустой каталог, пустой поиск и пустой фильтр требуют разных действий.
class EvLibraryEmptyState extends StatelessWidget {
  const EvLibraryEmptyState({super.key, required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final empty = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.games.isEmpty,
    );
    final view = context.watch<LibraryViewBloc>().state;
    final ev = context.ev;
    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: EvLibraryEmpty(
            title: l.libraryEmpty,
            subtitle: '',
            titleLabel: l.libraryEmpty,
            note: l.libraryEmptyNote,
            scanLabel: l.findInstalledGames,
            sourceLabel: l.addGameSource,
            dropLabel: l.libraryDropHint,
            onScan: onScan,
            onMagnet: () => showAddGameDialog(context),
            footer: const SizedBox.shrink(),
          ),
        ),
      );
    }
    final searching = view.query.trim().isNotEmpty;
    final title = searching
        ? l.nothingFound
        : view.shelf == Shelf.recent
        ? l.shelfRecentEmpty
        : l.shelfEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EvIcon(
              searching ? EvIcons.search : EvIcons.library,
              size: 32,
              color: ev.colors.ink3,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ev.text.display(28),
              semanticsLabel: title,
            ),
            const SizedBox(height: 22),
            EvGhostButton(
              label: searching ? l.libraryClearSearch : l.libraryResetFilters,
              height: 38,
              onPressed: () {
                final bloc = context.read<LibraryViewBloc>();
                bloc.add(
                  searching
                      ? const LibraryQueryChanged('')
                      : const LibraryShelfSelected(Shelf.all),
                );
                context.read<NavigationBloc>().add(
                  const SearchFocusRequested(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
