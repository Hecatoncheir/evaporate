import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../theme.dart';

/// Наигранное время — показание прибора, а не подпись: моно, крупно и с
/// табличными цифрами, чтобы при смене числа ничего не дёргалось.
class PlaytimeReadout extends StatelessWidget {
  const PlaytimeReadout({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) => Container(
    width: 186,
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.heroPanel,
      border: Border.all(color: AppColors.coverProgressTrack),
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L.of(context).inGame.toUpperCase(),
          style: context.text.label.copyWith(
            color: AppColors.coverText.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          formatDurationLabel(L.of(context), game.playtime),
          style: context.text.readout.copyWith(color: AppColors.coverText),
        ),
      ],
    ),
  );
}
