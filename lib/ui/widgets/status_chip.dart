import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import 'toned_chip.dart';

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

    return TonedChip(
      text: label,
      color: color,
      style: compact ? context.text.chip : context.text.captionStrong,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? EvaporateSpacing.tight : EvaporateSpacing.cluster,
        vertical: compact ? EvaporateSpacing.hair : EvaporateSpacing.line,
      ),
    );
  }
}
