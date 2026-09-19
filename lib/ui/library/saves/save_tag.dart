import 'package:flutter/material.dart';

import '../../theme.dart';

class SaveTag extends StatelessWidget {
  const SaveTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: EvaporateAlpha.subtle),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
      ),
      child: Text(text, style: context.text.tag.copyWith(color: color)),
    );
  }
}
