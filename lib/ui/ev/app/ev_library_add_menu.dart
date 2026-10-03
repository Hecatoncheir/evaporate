import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../library/add_game_dialog.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';

/// Один вход для добавления источника и поиска установленных игр.
class EvLibraryAddMenu extends StatefulWidget {
  const EvLibraryAddMenu({super.key, required this.onScan});
  final VoidCallback onScan;

  @override
  State<EvLibraryAddMenu> createState() => _EvLibraryAddMenuState();
}

class _EvLibraryAddMenuState extends State<EvLibraryAddMenu> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return MenuAnchor(
      childFocusNode: _focus,
      builder: (context, controller, child) => EvGhostButton(
        label: l.addGame,
        icon: EvIcons.folder,
        height: 38,
        focusNode: _focus,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => showAddGameDialog(context),
          leadingIcon: const EvIcon(EvIcons.magnet),
          child: Text(l.addGameSource),
        ),
        MenuItemButton(
          onPressed: widget.onScan,
          leadingIcon: const EvIcon(EvIcons.folder),
          child: Text(l.findInstalledGames),
        ),
      ],
    );
  }
}
