import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import 'engine_state_color.dart';
import 'pulse_dot.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: EvaporateSpacing.field),
      decoration: BoxDecoration(
        color: color.withValues(alpha: EvaporateAlpha.subtle),
        border: Border.all(color: color.withValues(alpha: EvaporateAlpha.rim)),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(
            color: color,
            size: EvaporateIconSize.dot,
            alive: status.state.blinks,
          ),
          const SizedBox(width: EvaporateSpacing.hair),
          Icon(icon, size: EvaporateIconSize.key, color: color),
          const SizedBox(width: EvaporateSpacing.gap),
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
