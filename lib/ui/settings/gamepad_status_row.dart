import 'package:flutter/material.dart';

import '../../input/gamepad_service.dart';
import '../../l10n/app_localizations.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/info_row.dart';

/// Подключён ли геймпад прямо сейчас. Слушаем сервис, а не настройки:
/// устройство появляется и пропадает само.
class GamepadStatusRow extends StatelessWidget {
  const GamepadStatusRow({super.key, required this.gamepad});

  final GamepadService gamepad;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamepadStatus>(
      valueListenable: gamepad.status,
      builder: (context, status, _) => InfoRow(
        label: L.of(context).gamepad,
        value: gamepadStatusLabel(L.of(context), status),
        valueColor: status.hasDevice
            ? context.colors.accent
            : context.colors.textSecondary,
      ),
    );
  }
}
