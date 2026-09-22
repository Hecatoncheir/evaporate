import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/library_effect.dart';
import '../../../models/shelf.dart';
import '../../theme.dart';
import '../../widgets/liquid/liquid_selection.dart';
import '../toolbar/shelf_button.dart';
import 'toolbar_well.dart';

class ShelfTabs extends StatefulWidget {
  const ShelfTabs({super.key, required this.counts});

  /// Сколько игр на каждой полке после поиска. Сама полка и её смена —
  /// из `LibraryViewBloc`: прежде они спускались сюда колбэком через
  /// четыре виджета, ни одному из которых не были нужны.
  final Map<Shelf, int> counts;

  @override
  State<ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends State<ShelfTabs> {
  final _targets = {for (final shelf in Shelf.values) shelf: GlobalKey()};

  @override
  Widget build(BuildContext context) {
    final shelf = context.select<LibraryViewBloc, Shelf>((b) => b.state.shelf);
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
                count: widget.counts[value] ?? 0,
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
    Shelf.installed => l.tabInstalled,
    Shelf.notInstalled => l.tabNotInstalled,
  };
}
