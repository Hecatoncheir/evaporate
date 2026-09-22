import 'package:flutter/material.dart';

import '../theme.dart';

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
      padding: const EdgeInsets.fromLTRB(
        EvaporateSpacing.panel,
        EvaporateSpacing.block,
        EvaporateSpacing.panel,
        EvaporateSpacing.block,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.label,
          ),
          const SizedBox(height: EvaporateSpacing.tight),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? context.text.readout : context.text.readoutLarge)
                .copyWith(
                  color: dim
                      ? colors.textSecondary
                      : (color ?? colors.textPrimary),
                ),
          ),
        ],
      ),
    );
  }
}
