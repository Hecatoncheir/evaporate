import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/library_effect.dart';
import '../../../models/shelf.dart';
import '../../theme.dart';
import '../../widgets/liquid/liquid_selection.dart';
import '../toolbar/shelf_button.dart';
import 'toolbar_well.dart';

class ShelfTabs extends StatefulWidget {
  const ShelfTabs({
    super.key,
    required this.shelf,
    required this.counts,
    required this.onShelf,
  });
  final Shelf shelf;
  final Map<Shelf, int> counts;
  final ValueChanged<Shelf> onShelf;

  @override
  State<ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends State<ShelfTabs> {
  final _targets = {for (final shelf in Shelf.values) shelf: GlobalKey()};

  @override
  Widget build(BuildContext context) => ToolbarWell(
    padding: const EdgeInsets.all(3),
    child: LiquidSelection(
      key: const ValueKey('shelf-liquid'),
      targetKey: () => _targets[widget.shelf],
      color: context.colors.selection,
      radius: EvaporateTheme.radiusControl,
      enabled: context.select<SettingsBloc, bool>(
        (b) =>
            b.state.libraryEffects &&
            b.state.isOn(LibraryEffect.liquidSelection),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final value in Shelf.values)
            ShelfButton(
              key: _targets[value],
              label: _label(L.of(context), value),
              count: widget.counts[value] ?? 0,
              active: value == widget.shelf,
              onTap: () => widget.onShelf(value),
            ),
        ],
      ),
    ),
  );

  static String _label(L l, Shelf shelf) => switch (shelf) {
    Shelf.all => l.tabAll,
    Shelf.installed => l.tabInstalled,
    Shelf.notInstalled => l.tabNotInstalled,
  };
}
