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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
              style: context.text.body.copyWith(
                color: valueColor,
                fontFamily: monospace ? EvaporateTheme.monoFontFamily : null,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
