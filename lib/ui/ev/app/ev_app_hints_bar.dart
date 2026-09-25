import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../input/gamepad_binding.dart';
import '../../../input/gamepad_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../services/download/download_engine.dart';
import '../../labels.dart';
import '../design/theme.dart';
import '../shell/ev_hints_bar.dart';
import 'ev_shell_status.dart';
import 'shell_hints.dart';

/// Строка подсказок прототипа на настоящих данных: клавиши или кнопки
/// геймпада по раскладке из настроек, а справа — скорости обмена, пока
/// что-то идёт, и состояние движка загрузок.
///
/// Скорости здесь, а не только на странице загрузок и в плашке верхней
/// полосы: человек уходит из загрузок в библиотеку и всё равно хочет
/// знать, едет ли раздача, а плашка в окне уже 1000 точек прячется.
class EvAppHintsBar extends StatelessWidget {
  const EvAppHintsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Только раскладка, движок и показания: снимок задач приходит каждую
    // секунду, а этой строке до задач дела нет.
    final binding = context.select<SettingsBloc, GamepadBinding>(
      (bloc) => bloc.state.gamepad,
    );
    final (engine, stats) = context
        .select<DownloadsBloc, (EngineState, EngineStats)>(
          (bloc) => (bloc.state.engine.state, bloc.state.stats),
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
        readout: stats.activeCount > 0 ? exchangeReadout(l, stats) : null,
      ),
    );
  }
}
