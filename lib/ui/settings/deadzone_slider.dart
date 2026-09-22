import 'package:flutter/material.dart';

import '../../input/gamepad_binding.dart';
import '../../input/input_scope.dart';
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

  static const _min = 0.2;
  static const _max = 0.9;
  static const _divisions = 14;

  void _set(double value) => onChanged(
    binding.copyWith(
      deadzone: value,
      // Порог отпускания держим ниже порога срабатывания,
      // иначе стик «дребезжит» на границе.
      releaseZone: value * 0.7,
    ),
  );

  /// Шаг с геймпада — ровно одно деление ползунка.
  void _step(int steps) {
    const step = (_max - _min) / _divisions;
    final next = (binding.deadzone + steps * step).clamp(_min, _max);
    // К ближайшему делению: иначе накопленная погрешность уводила бы
    // значение с делений, и подпись показывала бы «0.55» при 0.5499.
    _set(_min + ((next - _min) / step).round() * step);
  }

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
            // Геймпад приходит не клавишами, а действиями: влево и вправо
            // с него сдвигают значение через `AdjustValueIntent`.
            child: Actions(
              actions: {
                AdjustValueIntent: CallbackAction<AdjustValueIntent>(
                  onInvoke: (intent) {
                    _step(intent.steps);
                    return null;
                  },
                ),
              },
              child: Slider(
                value: binding.deadzone,
                min: _min,
                max: _max,
                divisions: _divisions,
                label: binding.deadzone.toStringAsFixed(2),
                onChanged: _set,
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
