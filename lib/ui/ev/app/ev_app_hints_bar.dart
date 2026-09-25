import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../input/gamepad_binding.dart';
import '../../../input/gamepad_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/download/download_engine.dart';
import '../../labels.dart';
import '../design/theme.dart';
import '../shell/ev_hints_bar.dart';
import 'ev_shell_status.dart';
import 'shell_hints.dart';

/// Строка подсказок прототипа на настоящих данных: клавиши или кнопки
/// геймпада по раскладке из настроек и состояние движка загрузок справа.
class EvAppHintsBar extends StatelessWidget {
  const EvAppHintsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Только раскладка и движок: строка ни на что больше не смотрит, а
    // снимок загрузок приходит каждую секунду.
    final binding = context.select<SettingsBloc, GamepadBinding>(
      (bloc) => bloc.state.gamepad,
    );
    final engine = context.select<DownloadsBloc, EngineState>(
      (bloc) => bloc.state.engine.state,
    );
    final (_, tone) = engineReadout(l, engine);
    final gamepad = context.read<GamepadService>();
    return ValueListenableBuilder<GamepadStatus>(
      valueListenable: gamepad.status,
      builder: (context, status, _) => EvHintsBar(
        hints: shellHints(
          l,
          binding,
          gamepad: binding.enabled && status.hasDevice,
        ),
        status: engineStateLabel(l, engine).toUpperCase(),
        statusColor: evStatusColor(context.evc, tone),
      ),
    );
  }
}
