import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import 'featured_actions.dart';
import 'featured_eyebrow.dart';

/// Надпись на крупном кадре: метка, название, описание и клавиши.
///
/// Занимает долю кадра, а не фиксированные 452 точки: на широкоформатном
/// окне такой блок оставлял название обрезанным посреди пустого кадра.
class FeaturedPoster extends StatelessWidget {
  const FeaturedPoster({
    super.key,
    required this.game,
    required this.width,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;

  /// Ширина всего кадра; сама надпись занимает её долю.
  final double width;

  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final textWidth = (width * 0.44).clamp(320.0, 760.0);
    return Positioned(
      left: EvaporateLayout.gutter,
      top: 24,
      bottom: 24,
      width: textWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeaturedEyebrow(game: game),
          const Spacer(),
          Text(
            game.title.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.coverText,
              fontFamily: EvaporateTheme.displayFontFamily,
              // Крупнее не влезает: под названием стоят описание в две
              // строки и ряд клавиш.
              fontSize: 32,
              height: 1.04,
              fontWeight: FontWeight.w800,
              // Разряд положительный: у широкого шрифта прижатые
              // заглавные слипаются.
              letterSpacing: 0.6,
              shadows: [
                Shadow(blurRadius: 18, color: AppColors.coverTextShadow),
              ],
            ),
          ),
          const SizedBox(height: EvaporateSpacing.cluster),
          Text(
            game.details.description?.trim().isNotEmpty == true
                ? game.details.description!
                : L.of(context).featuredFallbackDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.note.copyWith(
              color: AppColors.heroBody,
              height: 1.4,
            ),
          ),
          const SizedBox(height: EvaporateSpacing.block),
          FeaturedActions(game: game, onOpen: onOpen, onPrimary: onPrimary),
        ],
      ),
    );
  }
}
