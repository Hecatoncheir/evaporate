import 'package:flutter/material.dart';

/// Расставляет три органа панели по ширине окна.
///
/// Выше [_wide] все три встают в строку с просветами, ниже — плотнее, а в
/// узком окне становятся столбцом: втиснутые в строку, они начинают резать
/// друг другу подписи.
class ToolbarLayout extends StatelessWidget {
  const ToolbarLayout({
    super.key,
    required this.filters,
    required this.actions,
    required this.search,
  });

  /// Выше этой ширины все три органа встают в строку с просветами.
  static const _wide = 1340.0;

  /// Ниже этой — в строку не влезают вовсе и становятся столбцом.
  static const _narrow = 760.0;

  final Widget filters;
  final Widget actions;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= _wide) {
          return Row(
            children: [
              filters,
              const Spacer(),
              actions,
              const Spacer(),
              search,
            ],
          );
        }
        if (box.maxWidth >= _narrow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filters,
              const SizedBox(width: 6),
              Expanded(child: actions),
              const SizedBox(width: 6),
              search,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerLeft, child: filters),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: search),
            const SizedBox(height: 8),
            Align(child: actions),
          ],
        );
      },
    );
  }
}
