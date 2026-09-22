import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../labels.dart';
import '../../theme.dart';

/// Счётчик обзоров: значок и число.
///
/// Диктору уходит цельная фраза, а значок с числом из объявления убраны:
/// «палец вверх, пятьдесят четыре тысячи» не складывается в смысл.
class ReviewCount extends StatelessWidget {
  const ReviewCount({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textSecondary;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: EvaporateIconSize.tiny, color: color),
            const SizedBox(width: EvaporateSpacing.line),
            Text(
              countLabel(L.of(context), value),
              style: context.text.captionMuted,
            ),
          ],
        ),
      ),
    );
  }
}
