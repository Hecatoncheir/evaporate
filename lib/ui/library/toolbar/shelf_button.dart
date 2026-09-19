import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/liquid_selection.dart';

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
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: active ? colors.onSelection : colors.textSecondary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                style: context.text.body.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: context.text.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
