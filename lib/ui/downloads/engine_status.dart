import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/pulse_dot.dart';
import 'engine_state_color.dart';

class EngineStatusChip extends StatelessWidget {
  const EngineStatusChip({super.key, required this.status});

  final EngineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.engine(status.state);
    final icon = switch (status.state) {
      EngineState.ready => Icons.check_circle_outline_rounded,
      EngineState.starting => Icons.hourglass_empty_rounded,
      EngineState.failed => Icons.error_outline_rounded,
      EngineState.stopped => Icons.stop_circle_outlined,
    };
    final label =
        status.message ??
        L
            .of(context)
            .engineStatus(engineStateLabel(L.of(context), status.state));

    return Container(
      constraints: const BoxConstraints(minHeight: 38, maxWidth: 270),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: EvaporateAlpha.subtle),
        border: Border.all(color: color.withValues(alpha: EvaporateAlpha.rim)),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Светодиод мигает, только пока движок поднимается или сломан:
          // ровно горящая точка рядом со словом «готов» ничего не добавляет.
          PulseDot(
            color: color,
            size: 6,
            alive:
                status.state == EngineState.starting ||
                status.state == EngineState.failed,
          ),
          const SizedBox(width: 3),
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.chip.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class EngineFailure extends StatelessWidget {
  const EngineFailure({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.danger.withValues(alpha: EvaporateAlpha.subtle),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        border: Border.all(
          color: context.colors.danger.withValues(alpha: EvaporateAlpha.rim),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? L.of(context).engineStopped,
              style: context.text.body.copyWith(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
