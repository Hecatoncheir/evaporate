import 'package:flutter/material.dart';

import '../../input/gamepad_binding.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Мёртвая зона стика: ниже неё отклонение не считается движением.
class DeadzoneSlider extends StatelessWidget {
  const DeadzoneSlider({
    super.key,
    required this.binding,
    required this.onChanged,
  });

  final GamepadBinding binding;
  final ValueChanged<GamepadBinding> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(L.of(context).deadZone, style: context.text.body),
        ),
        Expanded(
          child: MediaQuery(
            // В направленном режиме Slider обрабатывает только ←/→.
            // ↑/↓ проходят к FocusTraversal и двигают курсор дальше
            // по настройкам.
            data: MediaQuery.of(context)
                .copyWith(navigationMode: NavigationMode.directional),
            child: Slider(
              value: binding.deadzone,
              min: 0.2,
              max: 0.9,
              divisions: 14,
              label: binding.deadzone.toStringAsFixed(2),
              onChanged: (value) => onChanged(
                binding.copyWith(
                  deadzone: value,
                  // Порог отпускания держим ниже порога срабатывания,
                  // иначе стик «дребезжит» на границе.
                  releaseZone: value * 0.7,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            binding.deadzone.toStringAsFixed(2),
            style: context.text.note,
          ),
        ),
      ],
    );
  }
}
