import 'package:flutter/material.dart';

import '../theme.dart';

/// Предупреждение строкой: значок и текст цветом предупреждения.
///
/// Было выписано дважды побайтово — в прокси и в уведомлениях, — и копии
/// ничем не различались, кроме места, где стояли.
class InlineWarning extends StatelessWidget {
  const InlineWarning(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: EvaporateIconSize.key,
          color: context.colors.warning,
        ),
        const SizedBox(width: EvaporateSpacing.gap),
        Expanded(child: Text(text, style: context.text.warning)),
      ],
    );
  }
}
