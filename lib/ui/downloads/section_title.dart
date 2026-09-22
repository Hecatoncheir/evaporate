import 'package:flutter/material.dart';

import '../theme.dart';

/// Подпись раздела колонки загрузок с числом рядом.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Подпись на корпусе, а не заголовок абзаца: моноширинная, заглавными,
    // а число рядом — фирменным цветом, чтобы читалось как показание.
    return Padding(
      padding: const EdgeInsets.only(bottom: EvaporateSpacing.field),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: context.text.label),
          if (trailing != null) ...[
            const SizedBox(width: EvaporateSpacing.gap),
            Text(
              trailing!,
              style: context.text.label.copyWith(color: context.colors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
