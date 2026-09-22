import 'package:flutter/material.dart';

import 'shell_footer_strip.dart';
import 'shell_panel.dart';
import 'top_bar.dart';

/// Раскладка окна: обойма сверху, панель разделов, подвал.
class ShellLayout extends StatelessWidget {
  const ShellLayout({super.key});

  /// Ниже этой ширины поля ужимаются: каждая точка нужна содержимому.
  static const _compactWidth = 980.0;

  /// Ниже этой высоты подвал убирается совсем — иначе не остаётся места
  /// самим разделам.
  static const _shortHeight = 520.0;

  /// Поле между краем окна и содержимым: в узком окне меньше, каждая точка
  /// ширины там нужна содержимому.
  ///
  /// Не приватное, потому что от него зависит чужое правило: полоса
  /// изменения размера у края окна не должна доставать до верхней рейки,
  /// иначе нажатие на её клавишу уйдёт в системный цикл изменения размера.
  /// Здесь, а не у `AppShell`: применяет их раскладка, и за ними она
  /// ходила к оболочке, которая импортирует её саму.
  static const compactInset = 6.0;
  static const wideInset = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < _compactWidth;
        final inset = compact ? compactInset : wideInset;
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
          child: Column(
            children: [
              ConceptTopBar(compact: compact),
              const SizedBox(height: 10),
              const Expanded(child: ShellPanel()),
              if (box.maxHeight >= _shortHeight) ...[
                const SizedBox(height: 6),
                ShellFooterStrip(width: box.maxWidth),
              ],
            ],
          ),
        );
      },
    );
  }
}
