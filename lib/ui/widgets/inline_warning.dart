import 'package:flutter/material.dart';

import '../theme.dart';

/// Предупреждение строкой: значок и текст цветом предупреждения — или
/// ошибки, если [danger].
///
/// Было выписано трижды — в прокси, в уведомлениях и под действиями игры, —
/// и копии различались только цветом и значком.
class InlineWarning extends StatelessWidget {
  const InlineWarning(this.text, {super.key, this.danger = false});

  final String text;

  /// Не предостережение, а случившаяся ошибка: запуск не удался, загрузка
  /// сорвалась.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          danger ? Icons.error_outline : Icons.warning_amber_rounded,
          size: EvaporateIconSize.key,
          color: color,
        ),
        const SizedBox(width: EvaporateSpacing.gap),
        Expanded(
          child: Text(text, style: context.text.warning.copyWith(color: color)),
        ),
      ],
    );
  }
}
