import 'package:flutter/material.dart';

import '../../theme.dart';

/// Расставляет три органа панели по её ширине.
///
/// Переносом: пока влезают, все трое стоят строкой — полки слева, поиск
/// справа, добавление между ними; не влезают — правые уходят следующей
/// строкой, а не сжимаются. Прежде было три раскладки по порогам ширины,
/// и в самой узкой органы вставали столбцом в три строки: в окне 900×620
/// панель съедала высоту первого ряда обложек. Сжатая же строка резала
/// подпись «Добавить игру» надвое.
///
/// Ширину перенос берёт всю: иначе он сжимается по своей строке, и
/// разносить органы по краям ему становится нечем.
class ToolbarLayout extends StatelessWidget {
  const ToolbarLayout({
    super.key,
    required this.filters,
    required this.actions,
    required this.search,
  });

  final Widget filters;
  final Widget actions;
  final Widget search;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: EvaporateSpacing.tight,
      runSpacing: EvaporateSpacing.gap,
      children: [filters, actions, search],
    ),
  );
}
