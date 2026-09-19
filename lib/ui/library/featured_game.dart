import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../theme.dart';
import 'effects/hero_sweep.dart';
import 'featured/featured_art.dart';
import 'featured/featured_compact_bar.dart';
import 'featured/featured_frame.dart';
import 'featured/featured_poster.dart';
import 'featured/playtime_readout.dart';
import 'shots_backdrop.dart';

/// Крупная обложка выбранной игры над полкой.
///
/// Кадр держит весь экран: библиотека начинается не со списка, а с той
/// игры, к которой человек вернулся. Поэтому обложка идёт во всю ширину, а
/// надпись лежит на затемнении слева — как на афише, а не как подпись под
/// картинкой.
///
/// В невысоком окне кадр не исчезает, а сжимается в одну полосу
/// ([compact]): выбранная игра и клавиша запуска — то, ради чего открывают
/// библиотеку, и прятать их там, где просто меньше места, неправильно.
/// Полностью кадр убирается только в совсем низком окне, где иначе не
/// осталось бы места самой полке.
class FeaturedGame extends StatelessWidget {
  const FeaturedGame({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
    this.compact = false,
    this.sweepEnabled = false,
    this.shotsEnabled = false,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  /// Полоса вместо кадра: название в одну строку, клавиши справа, без
  /// описания и отдельного показания наигранного времени.
  final bool compact;

  /// Полоса света, проходящая по обложке. Настройка своя — см. [HeroSweep].
  final bool sweepEnabled;

  /// Кадры из игры вместо неподвижной обложки. Настройка своя — см.
  /// [ShotsBackdrop]; у игр без кадров остаётся обложка.
  final bool shotsEnabled;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = compact ? (6.0, 8.0) : (8.0, 10.0);
    return Padding(
      padding: EvaporateLayout.inset(top: top, bottom: bottom),
      child: SizedBox(
        // Выше полного кадра делать нельзя: в окне 1280x900 первый ряд
        // обложек уходит под нижний край, и полка перестаёт читаться с
        // одного взгляда.
        height: compact ? 128 : 238,
        child: FeaturedFrame(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              fit: StackFit.expand,
              children: [
                FeaturedArt(
                  game: game,
                  compact: compact,
                  sweep: sweepEnabled,
                  shots: shotsEnabled,
                ),
                if (compact)
                  FeaturedCompactBar(
                    game: game,
                    onOpen: onOpen,
                    onPrimary: onPrimary,
                  )
                else ...[
                  FeaturedPoster(
                    game: game,
                    width: box.maxWidth,
                    onOpen: onOpen,
                    onPrimary: onPrimary,
                  ),
                  Positioned(
                    right: 22,
                    bottom: 22,
                    child: PlaytimeReadout(game: game),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
