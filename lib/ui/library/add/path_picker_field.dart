import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/inset_tile.dart';

/// Строка выбора пути: подпись, выбранное значение и нажатие на всю
/// карточку.
///
/// Нажимается вся строка, а не значок в углу: человек целится в то, что
/// читает.
class PathPickerField extends StatelessWidget {
  const PathPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  final String label;

  /// Выбранный путь; `null` — ещё ничего не выбрано.
  final String? value;

  final IconData icon;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
      child: InsetTile(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: EvaporateSpacing.block,
          vertical: EvaporateSpacing.block,
        ),
        radius: EvaporateTheme.radiusPanel,
        child: Row(
          children: [
            Icon(
              icon,
              size: EvaporateIconSize.panel,
              color: colors.textSecondary,
            ),
            const SizedBox(width: EvaporateSpacing.cluster),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.captionMuted),
                  const SizedBox(height: EvaporateSpacing.hair),
                  Text(
                    value ?? L.of(context).tapToChoose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.body.copyWith(
                      color: value == null
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz, size: EvaporateIconSize.panel),
          ],
        ),
      ),
    );
  }
}
