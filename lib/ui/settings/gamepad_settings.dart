import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gamepads/gamepads.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_binding.dart';
import '../../input/gamepad_service.dart';
import '../../input/nav_action.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import 'capture_button_dialog.dart';
import 'deadzone_slider.dart';
import 'gamepad_binding_row.dart';
import 'gamepad_status_row.dart';
import 'setting_switch.dart';

/// Раздел «Управление»: состояние геймпада и переназначение кнопок.
class GamepadSettingsCard extends StatelessWidget {
  const GamepadSettingsCard({super.key});

  /// Действия, которые имеет смысл вешать на кнопки. Направления идут с
  /// D-pad и стика и не переназначаются.
  static const _assignable = <NavAction>[
    NavAction.confirm,
    NavAction.back,
    NavAction.primaryAction,
    NavAction.search,
    NavAction.nextSection,
    NavAction.prevSection,
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final gamepad = context.read<GamepadService>();
    final binding = store.state.gamepad;
    final l = L.of(context);

    void save(GamepadBinding next) =>
        store.add(SettingsChanged(store.state.copyWith(gamepad: next)));

    return SectionCard(
      title: l.controls,
      icon: Icons.sports_esports_outlined,
      trailing: TextButton.icon(
        onPressed: gamepad.refreshDevices,
        icon: const Icon(Icons.refresh, size: 16),
        label: Text(l.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GamepadStatusRow(gamepad: gamepad),
          const SizedBox(height: 4),
          SettingSwitch(
            value: binding.enabled,
            onChanged: (value) => save(binding.copyWith(enabled: value)),
            title: l.gamepadControls,
            note: l.gamepadNavigationNote,
          ),
          const SizedBox(height: 8),
          DeadzoneSlider(binding: binding, onChanged: save),
          const SizedBox(height: 12),
          Text(l.bindings, style: context.text.bodyStrong),
          const SizedBox(height: 8),
          for (final action in _assignable)
            GamepadBindingRow(
              action: action,
              buttons: binding.buttonsFor(action),
              onAssign: () => _assign(context, action),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () =>
                save(binding.copyWith(buttons: GamepadBinding.defaultButtons)),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(l.defaultBinding),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, NavAction action) async {
    final store = context.read<SettingsBloc>();
    final gamepad = context.read<GamepadService>();

    final button = await showDialog<GamepadButton>(
      context: context,
      builder: (_) => CaptureButtonDialog(action: action, gamepad: gamepad),
    );
    if (button == null) return;

    store.add(
      SettingsChanged(
        store.state.copyWith(
          gamepad: store.state.gamepad.assign(button, action),
        ),
      ),
    );
  }
}
