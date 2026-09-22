import 'package:flutter/material.dart';

import '../theme.dart';

/// Пара «подпись — значение» для блоков с информацией.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EvaporateSpacing.line),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: context.text.bodyMuted),
          ),
          Expanded(
            child: SelectableText(
              value,
              // Путь — ролью пути, как везде; но значение, а не
              // пояснение, поэтому цвет основной, а не приглушённый.
              style: (monospace ? context.text.path : context.text.body)
                  .copyWith(color: valueColor ?? context.colors.textPrimary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
