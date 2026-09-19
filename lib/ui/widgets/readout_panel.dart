import 'package:flutter/material.dart';

import '../theme.dart';
import 'readout_cell.dart';
import 'readout_row.dart';

/// Панель показаний: несколько граф в одном корпусе через волосяную черту.
///
/// Именно одна панель, а не набор карточек: это одно показание в нескольких
/// графах, и разъехавшиеся карточки читались бы как отдельные блоки. Стоит
/// она наверху экрана и отвечает на главный вопрос раздела до того, как
/// человек начнёт разбираться в подробностях ниже.
class ReadoutPanel extends StatelessWidget {
  const ReadoutPanel({super.key, required this.cells, this.wrapBelow = 680});

  final List<ReadoutCell> cells;

  /// Ширина, ниже которой графы перестают вставать в одну строку и
  /// выстраиваются по две: четыре узкие графы читаются хуже двух рядов.
  final double wrapBelow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.railBackground.withValues(
          alpha: HardwareSurfaceTheme.of(context).readoutOpacity,
        ),
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= wrapBelow || cells.length < 3) {
            return ReadoutRow(cells: cells);
          }
          final rows = <Widget>[];
          for (var i = 0; i < cells.length; i += 2) {
            final pair = cells.sublist(i, (i + 2).clamp(0, cells.length));
            if (rows.isNotEmpty) {
              rows.add(Divider(height: 1, thickness: 1, color: colors.outline));
            }
            rows.add(ReadoutRow(cells: pair));
          }
          return Column(children: rows);
        },
      ),
    );
  }
}
