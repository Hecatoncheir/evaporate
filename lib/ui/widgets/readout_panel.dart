import 'package:flutter/material.dart';

import '../theme.dart';

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
            return Row(children: _withBars(context, cells));
          }
          final rows = <Widget>[];
          for (var i = 0; i < cells.length; i += 2) {
            final pair = cells.sublist(i, (i + 2).clamp(0, cells.length));
            if (rows.isNotEmpty) {
              rows.add(Divider(height: 1, thickness: 1, color: colors.outline));
            }
            rows.add(Row(children: _withBars(context, pair)));
          }
          return Column(children: rows);
        },
      ),
    );
  }

  List<Widget> _withBars(BuildContext context, List<ReadoutCell> row) => [
    for (var i = 0; i < row.length; i++) ...[
      if (i > 0) Container(width: 1, height: 54, color: context.colors.outline),
      Expanded(child: row[i]),
    ],
  ];
}

/// Одна графа: подпись моношириной сверху, показание под ней.
class ReadoutCell extends StatelessWidget {
  const ReadoutCell({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
    this.dim = false,
    this.color,
  });

  final String label;
  final String value;

  /// Для показаний, которые не влезают в крупный кегль: дат и пар «1 / 3».
  final bool compact;

  /// Показание, которого пока нет.
  final bool dim;

  /// Цвет показания, если оно значит состояние, а не просто число.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontFamily: EvaporateTheme.monoFontFamily,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: dim ? colors.textSecondary : (color ?? colors.textPrimary),
              fontFamily: EvaporateTheme.monoFontFamily,
              fontSize: compact ? 14 : 21,
              height: 1,
              fontWeight: FontWeight.w700,
              // Табличные цифры: показание не должно дёргаться, когда
              // меняется одна цифра.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
