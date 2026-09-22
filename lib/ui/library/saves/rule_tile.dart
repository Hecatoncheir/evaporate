import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import '../../theme.dart';
import '../../widgets/inset_tile.dart';
import 'rule_label_row.dart';

class RuleTile extends StatelessWidget {
  const RuleTile({
    super.key,
    required this.rule,
    required this.exists,
    required this.onRemove,
  });

  final SavePathRule rule;

  /// Лежит ли папка на диске. `null` — ещё не проверяли, и молчим: сказать
  /// «на диске нет» о непроверенном значило бы соврать там, где человек
  /// решает, чинить ли правило.
  final bool? exists;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final missing = exists == false;

    return InsetTile(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            missing ? Icons.folder_off_outlined : Icons.folder_outlined,
            size: EvaporateIconSize.key,
            color: missing
                ? context.colors.textSecondary
                : context.colors.accent,
          ),
          const SizedBox(width: EvaporateSpacing.cluster),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RuleLabelRow(rule: rule, missing: missing),
                const SizedBox(height: EvaporateSpacing.line),
                SelectableText(rule.template, style: context.text.path),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: EvaporateIconSize.key),
            tooltip: L.of(context).removePath,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
