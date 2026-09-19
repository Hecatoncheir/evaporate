import 'package:flutter/material.dart';

import '../theme.dart';

/// Пояснение под настройкой — одним начертанием на всю страницу.
class SettingNote extends StatelessWidget {
  const SettingNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.text.paragraph);
}
