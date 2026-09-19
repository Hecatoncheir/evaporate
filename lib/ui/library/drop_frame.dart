import 'package:flutter/material.dart';

import '../theme.dart';

/// Рамка, показывающая границу приёмника: сюда можно бросить.
class DropFrame extends StatelessWidget {
  const DropFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        border: Border.all(color: context.colors.accent, width: 2),
      ),
      child: Center(child: child),
    );
  }
}
