import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

class PathSetting extends StatelessWidget {
  const PathSetting({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: EvaporateTheme.monoFontFamily,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onPick, child: Text(L.of(context).change)),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            tooltip: L.of(context).clear,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
