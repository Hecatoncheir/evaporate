import 'package:flutter/material.dart';

import '../theme.dart';

/// Пояснение на месте пустого раздела колонки.
class QueueHint extends StatelessWidget {
  const QueueHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: context.text.paragraph),
    );
  }
}
