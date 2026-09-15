import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'save_tag.dart';

class RuleTile extends StatelessWidget {
  const RuleTile({
    super.key,
    required this.rule,
    required this.gameDir,
    required this.onRemove,
  });

  final SavePathRule rule;
  final String? gameDir;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final resolved = rule.resolve(gameDir: gameDir);
    final exists =
        resolved != null &&
        (Directory(resolved).existsSync() || File(resolved).existsSync());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            exists ? Icons.folder_outlined : Icons.folder_off_outlined,
            size: 17,
            color: exists
                ? context.colors.accent
                : context.colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ruleLabelText(L.of(context), rule.label),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rule.platform != null)
                      SaveTag(
                        text: platformLabel(rule.platform!),
                        color: context.colors.textSecondary,
                      ),
                    if (!rule.isPortable) ...[
                      const SizedBox(width: 6),
                      SaveTag(
                        text: L.of(context).notPortablePath,
                        color: context.colors.warning,
                      ),
                    ],
                    if (!exists) ...[
                      const SizedBox(width: 6),
                      SaveTag(
                        text: L.of(context).missingOnDisk,
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  rule.template,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontFamily: EvaporateTheme.monoFontFamily,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            tooltip: L.of(context).removePath,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
