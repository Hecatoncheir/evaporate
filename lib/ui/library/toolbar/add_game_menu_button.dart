import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../add_game_dialog.dart';

/// «Добавить игру» — одна клавиша с меню на два способа.
///
/// Прежде рядом стояли две равные по виду клавиши, «Найти установленные
/// игры» и «Добавить игру», и обе делали одно: пополняли библиотеку.
/// Выбирать между ними приходилось до того, как станет понятно, чем они
/// различаются. Теперь выбор — внутри одного действия, и в панели у него
/// одно место.
///
/// Меню, а не расщеплённая клавиша: у расщеплённой две области нажатия и
/// две остановки фокуса, а сюда ходят и с клавиатуры, и с геймпада.
class AddGameMenuButton extends StatelessWidget {
  const AddGameMenuButton({super.key, required this.onScan});

  /// Поиск установленных игр — страницы: пока его окно открыто, она
  /// держит броски в окно при себе.
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, EvaporateLayout.controlHeight),
          padding: const EdgeInsets.only(
            left: EvaporateSpacing.field,
            right: EvaporateSpacing.gap,
          ),
        ),
        icon: const Icon(Icons.add, size: EvaporateIconSize.panel),
        // Подпись гибкая: сжатой клавише жёсткий ряд из слова и уголка
        // рисовал полосатую ленту переполнения — так было, пока панель
        // втискивала клавишу в строку. Штатная подпись клавиши
        // переносится по словам — этот ряд должен уметь то же.
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(l.addGame)),
            const Icon(Icons.arrow_drop_down, size: EvaporateIconSize.panel),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => showAddGameDialog(context),
          leadingIcon: const Icon(Icons.link, size: EvaporateIconSize.panel),
          child: Text(l.addGameSource),
        ),
        MenuItemButton(
          onPressed: onScan,
          leadingIcon: const Icon(
            Icons.folder_open_outlined,
            size: EvaporateIconSize.panel,
          ),
          child: Text(l.findInstalledGames),
        ),
      ],
    );
  }
}
