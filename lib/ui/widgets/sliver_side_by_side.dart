import 'package:flutter/widgets.dart';

/// Две колонки из сливеров: слева узкая фиксированной ширины, справа —
/// остальное; в узком окне — одна под другой.
///
/// Колонки в `Row` сливеры не кладутся, а длинный список справа обязан
/// остаться сливером, иначе он строит все строки разом. Обе колонки едут
/// одной прокруткой страницы.
class SliverSideBySide extends StatelessWidget {
  const SliverSideBySide({
    super.key,
    required this.wide,
    required this.leftWidth,
    required this.gap,
    required this.left,
    required this.right,
  });

  /// Рядом, а не одна под другой.
  final bool wide;
  final double leftWidth;

  /// Просвет между колонками.
  final double gap;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) return SliverMainAxisGroup(slivers: [left, right]);
    return SliverCrossAxisGroup(
      slivers: [
        SliverConstrainedCrossAxis(maxExtent: leftWidth, sliver: left),
        SliverCrossAxisExpanded(
          flex: 1,
          sliver: SliverPadding(
            padding: EdgeInsets.only(left: gap),
            sliver: right,
          ),
        ),
      ],
    );
  }
}
