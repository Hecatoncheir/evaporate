import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';

/// Значок в углу: установлена, запущена, не заладилось.
///
/// Плашка в тоне смысла: подложка тёмная, как у всего поверх обложки, —
/// на светлой картинке значок иначе пропадал бы, — но тронута цветом
/// состояния и окантована им. Стеклом, как у прототипа, не сделана:
/// размытие под каждой плиткой сетки, да ещё над каплями, стоило бы
/// кадров.
class CoverStatusBadge extends StatelessWidget {
  const CoverStatusBadge({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Идущая игра горит огнём главного действия, установленная — холодным
    // цветом готового: прежде обе были одного цвета, и запущенную в сетке
    // было не отличить.
    final (icon, tone) = switch (game.status) {
      GameStatus.running => (Icons.play_arrow_rounded, colors.primary),
      GameStatus.installed => (Icons.check_rounded, colors.accent),
      GameStatus.error => (Icons.priority_high_rounded, colors.danger),
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
            color: Color.alphaBlend(
              tone.withValues(alpha: EvaporateAlpha.subtle),
              AppColors.coverOverlay,
            ),
            border: Border.all(
              color: tone.withValues(alpha: EvaporateAlpha.rim),
            ),
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
          ),
          child: Icon(icon, size: EvaporateIconSize.key, color: tone),
        ),
      ),
    );
  }
}
