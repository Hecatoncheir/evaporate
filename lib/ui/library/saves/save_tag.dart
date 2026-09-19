import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/toned_chip.dart';

class SaveTag extends StatelessWidget {
  const SaveTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TonedChip(
      text: text,
      color: color,
      style: context.text.tag,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      radius: EvaporateTheme.radiusControl,
    );
  }
}
