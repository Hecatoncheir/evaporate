import 'package:flutter/material.dart';

import '../../theme.dart';

/// Утопленная ниша в обойме инструментов: поле поиска и полки сидят в
/// одинаковых углублениях, и расходиться им незачем — стоят они рядом.
class ToolbarWell extends StatelessWidget {
  const ToolbarWell({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.railBackground.withValues(
        alpha: EvaporateAlpha.veil,
      ),
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
      border: Border.all(
        color: context.colors.textPrimary.withValues(
          alpha: EvaporateAlpha.subtle,
        ),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}
