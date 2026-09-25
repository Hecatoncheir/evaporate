import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_binding.dart';
import '../../input/gamepad_service.dart';
import '../theme.dart';
import 'button_hints.dart';
import 'engine_readout.dart';
import 'shell_glass.dart';

/// Строка подсказок внизу окна: чем управлять прямо сейчас и едет ли
/// обмен.
///
/// Копирайт и ссылки на репозиторий отсюда убраны — это мебель сайта, а не
/// приложения: сорок точек высоты у них были заняты навсегда, а нажимали их
/// один раз в жизни. Ссылка на исходный код переехала в «О программе», где
/// и остальное про сборку.
class HintsBar extends StatelessWidget {
  const HintsBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Только раскладка геймпада: строка ни на что больше в настройках не
    // смотрит, а подписка целиком перестраивала её от смены темы.
    final gamepadBinding = context.select<SettingsBloc, GamepadBinding>(
      (b) => b.state.gamepad,
    );
    final gamepad = context.read<GamepadService>();
    // Кант — только на стыке с разделами: остальные края строки — края
    // самой панели.
    return ShellGlass(
      rim: const {AxisDirection.up},
      child: Container(
        height: EvaporateLayout.hintsHeight,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: EvaporateSpacing.card),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ValueListenableBuilder<GamepadStatus>(
                  valueListenable: gamepad.status,
                  builder: (context, status, _) => ButtonHints(
                    binding: gamepadBinding,
                    gamepadConnected:
                        gamepadBinding.enabled && status.hasDevice,
                  ),
                ),
              ),
            ),
            const SizedBox(width: EvaporateSpacing.panel),
            const EngineReadout(),
          ],
        ),
      ),
    );
  }
}
