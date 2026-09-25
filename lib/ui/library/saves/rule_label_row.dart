import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'save_tag.dart';

/// Метка правила и всё, что о нём стоит сказать рядом: система, на которой
/// оно действует, непереносимость пути, отсутствие папки на диске.
///
/// Перенос, а не строка: метку задаёт человек, и длинная вместе с тегами
/// вылезала за край узкой колонки.
class RuleLabelRow extends StatelessWidget {
  const RuleLabelRow({super.key, required this.rule, required this.missing});

  final SavePathRule rule;

  /// Папки на диске нет. Про непроверенное молчим — см. [RuleTile].
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Wrap(
      spacing: EvaporateSpacing.tight,
      runSpacing: EvaporateSpacing.line,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(ruleLabelText(l, rule.label), style: context.text.bodyStrong),
        if (rule.platform != null)
          SaveTag(
            text: platformLabel(rule.platform!),
            color: context.colors.textSecondary,
          ),
        if (!rule.isPortable)
          SaveTag(text: l.notPortablePath, color: context.colors.warning),
        if (missing)
          SaveTag(text: l.missingOnDisk, color: context.colors.textSecondary),
      ],
    );
  }
}
