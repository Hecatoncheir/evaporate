import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/inset_tile.dart';
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

    return InsetTile(
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
                // Перенос, а не строка: метку задаёт человек, и длинная
                // вместе с тегами вылезала за край узкой колонки.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      ruleLabelText(L.of(context), rule.label),
                      style: context.text.bodyStrong,
                    ),
                    if (rule.platform != null)
                      SaveTag(
                        text: platformLabel(rule.platform!),
                        color: context.colors.textSecondary,
                      ),
                    if (!rule.isPortable)
                      SaveTag(
                        text: L.of(context).notPortablePath,
                        color: context.colors.warning,
                      ),
                    if (!exists)
                      SaveTag(
                        text: L.of(context).missingOnDisk,
                        color: context.colors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(rule.template, style: context.text.path),
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
