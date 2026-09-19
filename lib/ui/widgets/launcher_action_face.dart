import 'package:flutter/material.dart';

import '../theme.dart';

/// Надпись на главной клавише: значок и слово.
class LauncherActionFace extends StatelessWidget {
  const LauncherActionFace({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(label, style: context.text.keycap.copyWith(color: color)),
    ],
  );
}
