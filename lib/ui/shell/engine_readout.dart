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
    // Разрядка уже, чем у метки: в строке состояния тесно. Цифры
    // табличные — показания меняются на глазах.
    final style = context.text.label.copyWith(
      letterSpacing: 0.7,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Мигает, только пока движок поднимается или сломан: ровно горящий
        // светодиод рядом со словом «готов» ничего не добавляет.
        PulseDot(
          color: color,
          size: 6,
          alive:
              status.state == EngineState.starting ||
              status.state == EngineState.failed,
        ),
        const SizedBox(width: 2),
        Text(
          engineStateLabel(l, status.state).toUpperCase(),
          style: style.copyWith(color: color),
        ),
        if (stats.activeCount > 0) ...[
          const SizedBox(width: 14),
          Icon(Icons.arrow_downward_rounded, size: 11, color: colors.primary),
          const SizedBox(width: 2),
          Text(speedLabel(l, stats.downloadSpeed), style: style),
          const SizedBox(width: 10),
          Icon(Icons.arrow_upward_rounded, size: 11, color: colors.accent),
          const SizedBox(width: 2),
          Text(speedLabel(l, stats.uploadSpeed), style: style),
        ],
      ],
    );
  }
}
