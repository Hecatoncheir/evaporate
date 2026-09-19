import 'package:flutter/material.dart';

import '../theme.dart';
import 'readout_cell.dart';

/// Графы показаний в строку, между ними — волосяная черта.
class ReadoutRow extends StatelessWidget {
  const ReadoutRow({super.key, required this.cells});

  final List<ReadoutCell> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0)
            Container(width: 1, height: 54, color: context.colors.outline),
          Expanded(child: cells[i]),
        ],
      ],
    );
  }
}
