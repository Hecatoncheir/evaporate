import 'package:flutter/material.dart';

import '../theme.dart';

/// Одно показание: значок, подпись на корпусе и число.
class DownloadMetric extends StatelessWidget {
  const DownloadMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: context.text.label),
              const SizedBox(height: 1),
              Text(value, style: context.text.figure),
            ],
          ),
        ],
      ),
    );
  }
}
