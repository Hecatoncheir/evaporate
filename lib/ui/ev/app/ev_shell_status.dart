import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../services/download/download_engine.dart';
import '../../labels.dart';
import '../design/tokens.dart';
import '../widgets/ev_surfaces.dart';

/// Состояние движка словами плашки и её тоном.
///
/// Словами «Движок готов», а не голым «Готов», как в строке подсказок:
/// плашка стоит рядом со скоростью, и без подлежащего непонятно, кто готов.
(String, EvStatus) engineReadout(L l, EngineState state) => switch (state) {
  EngineState.ready => (l.evEngineReady, EvStatus.ok),
  EngineState.starting => (l.evEngineStarting, EvStatus.busy),
  EngineState.stopped => (l.evEngineStopped, EvStatus.idle),
  EngineState.failed => (l.evEngineFailed, EvStatus.bad),
};

/// Цвет тона — тот же, что у точки плашки.
Color evStatusColor(EvColors c, EvStatus status) => switch (status) {
  EvStatus.ok => EvColors.ok,
  EvStatus.busy => c.cool,
  EvStatus.warn => EvColors.warn,
  EvStatus.bad => EvColors.bad,
  EvStatus.idle => c.ink4,
  EvStatus.news => c.hot2,
};

/// Скорости обмена одной строкой: приём и отдача всех раздач.
String exchangeReadout(L l, EngineStats stats) =>
    '↓ ${speedLabel(l, stats.downloadSpeed)}   '
    '↑ ${speedLabel(l, stats.uploadSpeed)}';

/// Скорость приёма в верхней полосе: складывается из всех раздач.
///
/// Сама подписана на блок загрузок — снимок приходит каждую секунду, и
/// перестраивать ради него весь каркас незачем.
class EvSpeedPill extends StatelessWidget {
  const EvSpeedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final speed = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.stats.downloadSpeed,
    );
    return EvPill(
      speedLabel(L.of(context), speed),
      status: speed > 0 ? EvStatus.busy : EvStatus.idle,
    );
  }
}

/// Состояние движка загрузок в верхней полосе.
class EvEnginePill extends StatelessWidget {
  const EvEnginePill({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<DownloadsBloc, EngineState>(
      (bloc) => bloc.state.engine.state,
    );
    final (label, status) = engineReadout(L.of(context), state);
    return EvPill(label, status: status);
  }
}
