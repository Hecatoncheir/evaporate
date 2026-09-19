import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';

/// Небольшая цветная метка статуса — используется в списке и в карточке игры.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final GameStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = gameStatusLabel(L.of(context), status);
    final color = switch (status) {
      GameStatus.notInstalled => context.colors.textSecondary,
      GameStatus.downloading => context.colors.primary,
      GameStatus.paused => context.colors.warning,
      GameStatus.installed => context.colors.accent,
      GameStatus.running => context.colors.accent,
      GameStatus.error => context.colors.danger,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: EvaporateAlpha.subtle),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
      ),
      child: Text(
        label,
        style: (compact ? context.text.chip : context.text.caption).copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
