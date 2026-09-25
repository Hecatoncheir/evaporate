import 'package:flutter/material.dart';

import '../theme.dart';

/// Сколько задач в работе. На выбранной клавише метка выворачивается:
/// тёплая метка на тёплой плашке выделения пропала бы.
class QueueBadge extends StatelessWidget {
  const QueueBadge({super.key, required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: context.motion.fast,
      curve: EvaporateMotion.ease,
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: EvaporateSpacing.line),
      decoration: BoxDecoration(
        color: selected ? colors.onSelection : colors.primaryFill,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
      ),
      child: Text(
        '$count',
        style: context.text.badge.copyWith(
          color: selected ? colors.selection : colors.onPrimary,
        ),
      ),
    );
  }
}
