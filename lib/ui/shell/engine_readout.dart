import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../services/download/download_engine.dart';
import '../downloads/engine_state_color.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/pulse_dot.dart';

/// Показания прибора в нижней строке: состояние движка и скорость обмена.
///
/// Стоят здесь, а не на экране загрузок: человек уходит из загрузок в
/// библиотеку и всё равно хочет знать, едет ли раздача. Числа — моношириной
/// с табличными цифрами, иначе строка дёргается на каждом обновлении.
class EngineReadout extends StatelessWidget {
  const EngineReadout({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Только движок и показания: снимок задач приходит каждую секунду, а
    // этой строке до задач дела нет.
    final (status, stats) = context
        .select<DownloadsBloc, (EngineStatus, EngineStats)>(
          (b) => (b.state.engine, b.state.stats),
        );
    final l = L.of(context);

    final color = colors.engine(status.state);
    // Моноширинный: показания меняются на глазах, а строка не дёргается.
    final style = context.text.statusLabel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulseDot(
          color: color,
          size: EvaporateIconSize.dot,
          alive: status.state.blinks,
        ),
        const SizedBox(width: EvaporateSpacing.hair),
        Text(
          engineStateLabel(l, status.state).toUpperCase(),
          style: style.copyWith(color: color),
        ),
        if (stats.activeCount > 0) ...[
          const SizedBox(width: EvaporateSpacing.block),
          Icon(
            Icons.arrow_downward_rounded,
            size: EvaporateIconSize.tiny,
            color: colors.primary,
          ),
          const SizedBox(width: EvaporateSpacing.hair),
          Text(speedLabel(l, stats.downloadSpeed), style: style),
          const SizedBox(width: EvaporateSpacing.cluster),
          Icon(
            Icons.arrow_upward_rounded,
            size: EvaporateIconSize.tiny,
            color: colors.accent,
          ),
          const SizedBox(width: EvaporateSpacing.hair),
          Text(speedLabel(l, stats.uploadSpeed), style: style),
        ],
      ],
    );
  }
}
