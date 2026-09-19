import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Запись в меню приложений: есть она или нет, и клавиша, которая это
/// меняет.
///
/// Сборка под Linux — папка с файлом, а не установленный пакет, поэтому в
/// меню приложений оно само не появляется.
class MenuEntryRow extends StatelessWidget {
  const MenuEntryRow({super.key, required this.inMenu, required this.onToggle});

  final bool inMenu;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              inMenu ? l.menuEntryAdded : l.menuEntryMissing,
              style: context.text.note,
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(inMenu ? l.menuEntryRemove : l.menuEntryAdd),
          ),
        ],
      ),
    );
  }
}
