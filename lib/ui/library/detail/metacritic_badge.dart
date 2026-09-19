import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/toned_chip.dart';

/// Оценка прессы. Отдельной плашкой: она о другом — не о том, что думают
/// игроки, а о том, что написали рецензенты, и слиться с долей обзоров ей
/// нельзя.
class MetacriticBadge extends StatelessWidget {
  const MetacriticBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Цвета — самого Metacritic, и они часть его оценки: зелёное, жёлтое и
    // красное там означают ровно то же, что у нас accent, warning и danger.
    final color = score >= 75
        ? colors.accent
        : (score >= 50 ? colors.warning : colors.danger);

    return Tooltip(
      message: L.of(context).metacriticScore(score),
      child: TonedChip(
        text: 'Metacritic $score',
        color: color,
        style: context.text.chip,
      ),
    );
  }
}
