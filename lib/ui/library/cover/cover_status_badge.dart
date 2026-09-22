import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';

/// Значок в углу: установлена, запущена, не заладилось.
class CoverStatusBadge extends StatelessWidget {
  const CoverStatusBadge({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (game.status) {
      GameStatus.running => (Icons.play_arrow_rounded, context.colors.accent),
      GameStatus.installed => (Icons.check_rounded, context.colors.accent),
      GameStatus.error => (Icons.priority_high_rounded, context.colors.danger),
      _ => (null, AppColors.transparent),
    };
    if (icon == null) return const SizedBox.shrink();

    // Сверху, а не снизу: снизу у плитки без обложки стоит название, и
    // значок налезал бы на него.
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(EvaporateSpacing.tight),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            // Кружок лежит на обложке, а не на фоне приложения: подложка
            // тёмная в обеих темах, иначе значок пропадал бы на светлых
            // картинках.
            color: AppColors.coverOverlay,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: EvaporateIconSize.key, color: color),
        ),
      ),
    );
  }
}
