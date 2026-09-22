import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/liquid/liquid_selection_ink.dart';

/// Полка с числом рядом — как вкладки в библиотеке Steam.
class ShelfButton extends StatelessWidget {
  const ShelfButton({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: EvaporateSpacing.line),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: active ? colors.onSelection : colors.textSecondary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(
            horizontal: EvaporateSpacing.cluster,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          ),
        ),
        child: LiquidSelectionInk(
          normalColor: colors.textSecondary,
          selectedColor: colors.onSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: active ? context.text.tabActive : context.text.tab,
              ),
              const SizedBox(width: EvaporateSpacing.tight),
              Text('$count', style: context.text.captionStrong),
            ],
          ),
        ),
      ),
    );
  }
}
