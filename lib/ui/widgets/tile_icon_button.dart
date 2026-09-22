import 'package:flutter/material.dart';

import '../theme.dart';

/// Клавиша со значком с краю плитки — восстановить, выгрузить, удалить.
///
/// От [IconAction] отличается нарочно: у той подложка с кантом, потому что
/// она живёт на графике загрузки, где голый значок терялся. Здесь ряд из
/// трёх таких клавиш на каждой строке списка превратился бы в частокол
/// цветных плашек, а строк на экране десятки.
class TileIconButton extends StatelessWidget {
  const TileIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Своего цвета у клавиши нет — он приходит от строки, которая знает,
  /// под курсором она или нет.
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: EvaporateIconSize.key),
    tooltip: tooltip,
    color: color,
    visualDensity: VisualDensity.compact,
  );
}
