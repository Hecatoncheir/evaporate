import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/toned_chip.dart';
import '../primary_action.dart';
import 'featured_actions.dart';
import 'featured_eyebrow.dart';
import 'featured_title.dart';

/// Надпись на крупном кадре: метка, название, плашки и клавиши.
///
/// Занимает долю кадра, а не фиксированные 452 точки: на широкоформатном
/// окне такой блок оставлял название обрезанным посреди пустого кадра.
///
/// Описания здесь нет, как у прототипа в низком кадре: под названием в две
/// строки его место в 238 точках заняли плашки, а живёт оно на странице
/// игры. Когда главная клавиша погашена, на месте плашек стоит причина:
/// погашенная клавиша без слова «почему» выглядит поломкой.
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
      top: EvaporateSpacing.wide,
      bottom: EvaporateSpacing.wide,
      width: textWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeaturedEyebrow(game: game),
          const Spacer(),
          FeaturedTitle(game.title),
          const SizedBox(height: EvaporateSpacing.gap),
          if (canDoPrimaryAction(game))
            _Chips(game: game)
          else
            _Note(game: game),
          const SizedBox(height: EvaporateSpacing.cluster),
          FeaturedActions(game: game, onOpen: onOpen, onPrimary: onPrimary),
        ],
      ),
    );
  }
}

/// Что с игрой, сколько она весит и сколько в неё играли.
///
/// Одной строкой: второй ряд плашек вытолкнул бы клавиши из кадра, поэтому
/// не влезшее срезается справа, а не переносится. Цвета — свои у кадра:
/// подложка под ним тёмная всегда, и цвета схемы, подобранные под светлый
/// корпус Картриджа, на ней терялись бы.
class _Chips extends StatelessWidget {
  const _Chips({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = context.text.chip;
    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        maxWidth: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: EvaporateSpacing.tight,
          children: [
            TonedChip(
              text: gameStatusLabel(l, game.status),
              color: AppColors.heroEyebrow,
              style: style,
            ),
            for (final text in [
              if (game.sizeBytes > 0) bytesLabel(l, game.sizeBytes),
              if (game.play.playtime > Duration.zero)
                l.playtime(formatDurationLabel(l, game.play.playtime)),
            ])
              TonedChip(text: text, color: AppColors.heroBody, style: style),
          ],
        ),
      ),
    );
  }
}

/// Почему главная клавиша погашена — облик строки под клавишей прототипа.
///
/// Причины две: у установленной игры не выбран исполняемый файл, а у
/// неустановленной нет источника, откуда качать.
class _Note extends StatelessWidget {
  const _Note({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = primaryActionFor(game) == PrimaryAction.play
        ? l.featuredNoExecutable
        : l.featuredNoSource;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: EvaporateIconSize.key,
            color: AppColors.heroEyebrow,
          ),
          const SizedBox(width: EvaporateSpacing.gap),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption.copyWith(
                color: AppColors.heroEyebrow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
