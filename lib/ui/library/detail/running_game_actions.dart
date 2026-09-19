import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Игра запущена: клавиша остановки и слово о том, что игра идёт.
class RunningGameActions extends StatelessWidget {
  const RunningGameActions({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
        const SizedBox(width: 14),
        Text(
          L.of(context).gameRunning,
          style: context.text.body.copyWith(color: context.colors.accent),
        ),
      ],
    );
  }
}
