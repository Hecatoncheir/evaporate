import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Прочитанные строки журнала — или слово о том, что их нет.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Text(L.of(context).logEmpty, style: context.text.note);
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(EvaporateSpacing.field),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
        border: Border.all(color: context.colors.outline),
      ),
      // Снизу вверх: важно последнее, а не первое.
      child: ListView(
        reverse: true,
        shrinkWrap: true,
        children: [
          for (final line in lines.reversed)
            SelectableText(line, style: context.text.log),
        ],
      ),
    );
  }
}
