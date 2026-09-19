import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';
import '../hero_sweep.dart';
import '../shots_backdrop.dart';

/// Сама картинка с затемнениями и пробегом света.
class FeaturedArt extends StatelessWidget {
  const FeaturedArt({
    super.key,
    required this.game,
    required this.compact,
    required this.sweep,
    required this.shots,
  });

  final Game game;
  final bool compact;
  final bool sweep;
  final bool shots;

  @override
  Widget build(BuildContext context) {
    final coverPath = game.coverPath;
    final fallback = Image.asset(
      'assets/branding/orbit_fall_hero.png',
      key: const ValueKey('featured-game-background-fallback'),
      fit: BoxFit.cover,
      alignment: const Alignment(0.2, 0.46),
      filterQuality: FilterQuality.medium,
    );

    return HeroSweep(
      enabled: sweep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Кадры из игры, а если их нет — обложка, а если нет и её —
          // наш собственный задник. Порядок здесь и есть вся логика:
          // подложка не обязана быть у каждой игры.
          ShotsBackdrop(
            shots: game.shotPaths,
            enabled: shots,
            fallback: coverPath == null
                ? fallback
                : Image.file(
                    File(coverPath),
                    key: const ValueKey('featured-game-background'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.heroShadeStrong,
                  AppColors.heroShadeMiddle,
                  AppColors.heroShadeClear,
                ],
                stops: [0, 0.5, 0.86],
              ),
            ),
          ),
          // В полосе клавиши стоят справа, прямо на картинке, и им нужна
          // своя подложка: в полном кадре правая половина остаётся
          // открытой, а здесь на ней белая надпись.
          if (compact)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.heroShadeStrong, AppColors.heroShadeClear],
                  stops: [0, 0.46],
                ),
              ),
            ),
          // Второе затемнение снизу: у надписи должна быть подложка
          // независимо от того, что на картинке.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.heroShadeMiddle, AppColors.heroShadeClear],
                stops: [0, 0.62],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
