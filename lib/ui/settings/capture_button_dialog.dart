import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../../input/gamepad_service.dart';
import '../../input/nav_action.dart';
import '../../l10n/app_localizations.dart';
import '../labels.dart';
import '../theme.dart';

/// Ждёт нажатия на геймпаде — надёжнее, чем угадывать раскладку контроллера.
class CaptureButtonDialog extends StatefulWidget {
  const CaptureButtonDialog({
    super.key,
    required this.action,
    required this.gamepad,
  });

  final NavAction action;
  final GamepadService gamepad;

  @override
  State<CaptureButtonDialog> createState() => CaptureButtonDialogState();
}

class CaptureButtonDialogState extends State<CaptureButtonDialog> {
  /// Кнопка, которая закрывает окно, ничего не назначая.
  static const cancelButton = GamepadButton.start;

  StreamSubscription<GamepadButton>? _subscription;

  @override
  void initState() {
    super.initState();
    // Пока окно открыто, нажатия не выполняют своих прежних действий под
    // ним — см. `GamepadService.capturing`.
    widget.gamepad.capturing = true;
    _subscription = widget.gamepad.buttonPresses.listen((button) {
      if (!mounted) return;
      // Start — отмена: иначе с геймпада окно не закрыть вовсе, любая
      // кнопка становилась назначением. Start в раскладке по умолчанию
      // нет, это кнопка «меню», и её жмут, чтобы выйти; назначить её
      // отсюда нельзя — о чём и говорит подсказка в окне.
      Navigator.pop(context, button == cancelButton ? null : button);
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
              style: context.text.prose,
              textAlign: TextAlign.center,
            ),
            Text(
              L
                  .of(context)
                  .captureCancelHint(
                    gamepadButtonLabel(L.of(context), cancelButton),
                  ),
              style: context.text.caption,
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
