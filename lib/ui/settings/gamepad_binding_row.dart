import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../../input/nav_action.dart';
import '../../l10n/app_localizations.dart';
import '../labels.dart';
import '../theme.dart';

/// Действие и кнопки, которые на него назначены, с клавишей «Назначить».
class GamepadBindingRow extends StatelessWidget {
  const GamepadBindingRow({
    super.key,
    required this.action,
    required this.buttons,
    required this.onAssign,
  });

  final NavAction action;
  final List<GamepadButton> buttons;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: EvaporateLayout.settingLabelWidth,
            child: Text(
              navActionLabel(L.of(context), action),
              style: context.text.body,
            ),
          ),
          Expanded(
            child: Text(
              buttons.isEmpty
                  ? L.of(context).unassigned
                  : buttons
                        .map((b) => gamepadButtonLabel(L.of(context), b))
                        .join(', '),
              style: context.text.note.copyWith(
                color: buttons.isEmpty
                    ? context.colors.warning
                    : context.colors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onAssign, child: Text(L.of(context).assign)),
        ],
      ),
    );
  }
}
