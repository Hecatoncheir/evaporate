import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gamepads/gamepads.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_binding.dart';
import '../../input/gamepad_service.dart';
import '../../input/nav_action.dart';
import '../../l10n/app_localizations.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
          _status(gamepad),
          const SizedBox(height: 4),
          SwitchListTile(
            value: binding.enabled,
            onChanged: (value) => save(binding.copyWith(enabled: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(l.gamepadControls, style: context.text.body),
            subtitle: Text(
              l.gamepadNavigationNote,
              style: context.text.caption,
            ),
          ),
          const SizedBox(height: 8),
          _deadzone(context, binding, save),
          const SizedBox(height: 12),
          Text(l.bindings, style: context.text.bodyStrong),
          const SizedBox(height: 8),
          for (final action in _assignable)
            _BindingRow(
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

  /// Подключён ли геймпад прямо сейчас. Слушаем сервис, а не настройки:
  /// устройство появляется и пропадает само.
  Widget _status(GamepadService gamepad) =>
      ValueListenableBuilder<GamepadStatus>(
        valueListenable: gamepad.status,
        builder: (context, status, _) => InfoRow(
          label: L.of(context).gamepad,
          value: gamepadStatusLabel(L.of(context), status),
          valueColor: status.hasDevice
              ? context.colors.accent
              : context.colors.textSecondary,
        ),
      );

  /// Мёртвая зона стика: ниже неё отклонение не считается движением.
  Widget _deadzone(
    BuildContext context,
    GamepadBinding binding,
    void Function(GamepadBinding) save,
  ) => Row(
    children: [
      SizedBox(
        width: 220,
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
            onChanged: (value) => save(
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

  Future<void> _assign(BuildContext context, NavAction action) async {
    final store = context.read<SettingsBloc>();
    final gamepad = context.read<GamepadService>();

    final button = await showDialog<GamepadButton>(
      context: context,
      builder: (_) => _CaptureButtonDialog(action: action, gamepad: gamepad),
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

class _BindingRow extends StatelessWidget {
  const _BindingRow({
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
            width: 220,
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

/// Ждёт нажатия на геймпаде — надёжнее, чем угадывать раскладку контроллера.
class _CaptureButtonDialog extends StatefulWidget {
  const _CaptureButtonDialog({required this.action, required this.gamepad});

  final NavAction action;
  final GamepadService gamepad;

  @override
  State<_CaptureButtonDialog> createState() => _CaptureButtonDialogState();
}

class _CaptureButtonDialogState extends State<_CaptureButtonDialog> {
  StreamSubscription<GamepadButton>? _subscription;

  @override
  void initState() {
    super.initState();
    // Пока окно открыто, нажатия не выполняют своих прежних действий под
    // ним — см. `GamepadService.capturing`.
    widget.gamepad.capturing = true;
    _subscription = widget.gamepad.buttonPresses.listen((button) {
      if (mounted) Navigator.pop(context, button);
    });
  }

  @override
  void dispose() {
    widget.gamepad.capturing = false;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        L.of(context).buttonFor(navActionLabel(L.of(context), widget.action)),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 44,
              color: context.colors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              L.of(context).pressAnyButton,
              style: const TextStyle(fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<GamepadStatus>(
              valueListenable: widget.gamepad.status,
              builder: (context, status, _) => Text(
                status.hasDevice
                    ? gamepadStatusLabel(L.of(context), status)
                    : L.of(context).gamepadNotFound,
                textAlign: TextAlign.center,
                style: context.text.caption.copyWith(
                  color: status.hasDevice
                      ? context.colors.textSecondary
                      : context.colors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
      ],
    );
  }
}
