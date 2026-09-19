import 'package:flutter/material.dart';

import '../theme.dart';

/// Переключатель с подписью справа, без отступов `SwitchListTile`: для
/// карточек, где строки стоят плотно и выравниваются по левому краю.
class LabeledSwitchRow extends StatelessWidget {
  const LabeledSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: context.text.body)),
      ],
    );
  }
}
