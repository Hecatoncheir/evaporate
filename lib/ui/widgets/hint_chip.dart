import 'package:flutter/material.dart';

import '../theme.dart';

/// Подсказка клавиши: знак клавиши или кнопки в рамке и что она делает.
class HintChip extends StatelessWidget {
  const HintChip({super.key, required this.glyph, required this.label});

  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: EvaporateSpacing.line,
            vertical: EvaporateSpacing.hair,
          ),
          decoration: BoxDecoration(
            color: context.colors.surfaceHigh,
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
            border: Border.all(color: context.colors.outline),
          ),
          child: Text(
            glyph,
            style: context.text.tagStrong.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: EvaporateSpacing.line),
        Text(
          label,
          style: context.text.small.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
