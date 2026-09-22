import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_binding.dart';
import '../../input/gamepad_service.dart';
import '../theme.dart';
import '../widgets/button_hints.dart';
import 'engine_readout.dart';

/// Нижняя строка: подсказки управления и показания движка.
///
/// Копирайт и ссылки на репозиторий отсюда убраны — это мебель сайта, а не
/// приложения: сорок точек высоты у них были заняты навсегда, а нажимали их
/// один раз в жизни. Ссылка на исходный код переехала в «О программе», где
/// и остальное про сборку.
///
/// Осталось то, что меняется: чем управлять прямо сейчас и едет ли обмен.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    // Только раскладка геймпада: подвал ни на что больше в настройках не
    // смотрит, а подписка целиком перестраивала его от смены темы.
    final gamepadBinding = context.select<SettingsBloc, GamepadBinding>(
      (b) => b.state.gamepad,
    );
    final gamepad = context.read<GamepadService>();
    return Container(
      height: EvaporateLayout.footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: context.colors.railBackground.withValues(
          alpha: EvaporateAlpha.veil,
        ),
        border: Border(
          top: BorderSide(
            color: context.colors.outline.withValues(
              alpha: EvaporateAlpha.soft,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ValueListenableBuilder<GamepadStatus>(
                valueListenable: gamepad.status,
                builder: (context, status, _) => ButtonHints(
                  binding: gamepadBinding,
                  gamepadConnected: gamepadBinding.enabled && status.hasDevice,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const EngineReadout(),
        ],
      ),
    );
  }
}
