import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/library_effect.dart';
import '../../../models/shelf.dart';
import '../../theme.dart';
import '../../widgets/liquid/liquid_selection.dart';
import '../toolbar/shelf_button.dart';
import 'toolbar_well.dart';

/// Вкладки полок с числами.
///
/// Полка, её смена и числа — из `LibraryViewBloc` и библиотеки: прежде
/// они спускались сюда колбэком и списком найденного через четыре
/// виджета, ни одному из которых не были нужны. Числа считаются по
/// найденному, а не по всей библиотеке: полка показывает, сколько игр на
/// ней осталось после поиска.
class ShelfTabs extends StatefulWidget {
  const ShelfTabs({super.key});

  @override
  State<ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends State<ShelfTabs> {
  final _targets = {for (final shelf in Shelf.values) shelf: GlobalKey()};

  @override
  Widget build(BuildContext context) {
    final view = context.watch<LibraryViewBloc>().state;
    final shelf = view.shelf;
    final found = view.found(
      context.select<LibraryBloc, List<Game>>((b) => b.state.games),
    );
    return ToolbarWell(
      padding: const EdgeInsets.all(EvaporateLayout.wellInset),
      child: LiquidSelection(
        key: const ValueKey('shelf-liquid'),
        targetKey: () => _targets[shelf],
        color: context.colors.selection,
        radius: EvaporateTheme.radiusControl,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.appearance.shows(LibraryEffect.liquidSelection),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in Shelf.values)
              ShelfButton(
                key: _targets[value],
                label: _label(L.of(context), value),
                count: gamesOnShelf(found, value).length,
                active: value == shelf,
                onTap: () => context.read<LibraryViewBloc>().add(
                  LibraryShelfSelected(value),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _label(L l, Shelf shelf) => switch (shelf) {
    Shelf.all => l.tabAll,
    Shelf.recent => l.tabRecent,
    Shelf.installed => l.tabInstalled,
    Shelf.notInstalled => l.tabNotInstalled,
  };
}
