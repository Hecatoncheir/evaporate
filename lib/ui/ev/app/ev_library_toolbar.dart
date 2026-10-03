import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/library_effect.dart';
import '../../../models/shelf.dart';
import '../../library/toolbar/library_search_field.dart';
import '../../library/toolbar/liquid_selection_ink.dart';
import '../../widgets/liquid/liquid_selection.dart';
import '../design/theme.dart';
import '../glass/ev_glass.dart';
import '../library/library_layout.dart';
import '../widgets/ev_surfaces.dart';
import 'ev_library_add_menu.dart';

/// Стекло и пропорции прототипа, фильтры и действия настоящей библиотеки.
class EvLibraryToolbar extends StatelessWidget {
  const EvLibraryToolbar({
    super.key,
    required this.searchFocus,
    required this.onScan,
    required this.onReturnToGames,
  });
  final FocusNode searchFocus;
  final VoidCallback onScan, onReturnToGames;

  @override
  Widget build(BuildContext context) {
    final layout = EvLibraryLayout.of(MediaQuery.sizeOf(context));
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.gutter, 24, layout.gutter, 0),
      child: EvPanel(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const KeyedSubtree(
                key: ValueKey('library-filter-group'),
                child: _Filters(),
              ),
              KeyedSubtree(
                key: const ValueKey('library-actions-group'),
                child: EvLibraryAddMenu(onScan: onScan),
              ),
              LibrarySearchField(
                focusNode: searchFocus,
                onReturnToGames: onReturnToGames,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters();
  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  final _targets = {for (final value in Shelf.values) value: GlobalKey()};

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final l = L.of(context);
    final view = context.watch<LibraryViewBloc>().state;
    final games = view.found(
      context.select<LibraryBloc, List<Game>>((bloc) => bloc.state.games),
    );
    final labels = {
      Shelf.all: l.tabAll,
      Shelf.recent: l.tabRecent,
      Shelf.installed: l.tabInstalled,
      Shelf.notInstalled: l.tabNotInstalled,
    };
    final animated = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.appearance.shows(LibraryEffect.liquidSelection),
    );
    return EvGlass(
      style: EvGlassStyle.chip,
      backdrop: false,
      borderRadius: ev.radii.bPill,
      tint: ev.colors.ground.withValues(alpha: .3),
      padding: const EdgeInsets.all(2),
      child: LiquidSelection(
        key: const ValueKey('shelf-liquid'),
        targetKey: () => _targets[view.shelf],
        color: ev.colors.ink.withValues(alpha: .1),
        radius: ev.radii.pill,
        enabled: animated,
        child: Wrap(
          children: [
            for (final value in Shelf.values)
              Semantics(
                selected: value == view.shelf,
                child: TextButton(
                  key: _targets[value],
                  onPressed: () => context.read<LibraryViewBloc>().add(
                    LibraryShelfSelected(value),
                  ),
                  style: TextButton.styleFrom(
                    textStyle: ev.text.data,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: ev.radii.bPill),
                  ),
                  child: LiquidSelectionInk(
                    normalColor: ev.colors.ink3,
                    selectedColor: ev.colors.ink,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(labels[value]!),
                        const SizedBox(width: 6),
                        Text(
                          '${gamesOnShelf(games, value).length}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
