import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';

import 'hero_sweep.dart';
import '../../l10n/app_localizations.dart';

/// Крупная обложка выбранной игры над полкой.
///
/// Кадр держит весь экран: библиотека начинается не со списка, а с той
/// игры, к которой человек вернулся. Поэтому обложка идёт во всю ширину, а
/// надпись лежит на затемнении слева — как на афише, а не как подпись под
/// картинкой.
class FeaturedGame extends StatelessWidget {
  const FeaturedGame({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
    this.sweepEnabled = false,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  /// Полоса света, проходящая по обложке. Настройка своя — см. [HeroSweep].
  final bool sweepEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final playable = game.status != GameStatus.installed || game.canLaunch;
    final coverPath = game.coverPath;
    final fallback = Image.asset(
      'assets/branding/orbit_fall_hero.png',
      key: const ValueKey('featured-game-background-fallback'),
      fit: BoxFit.cover,
      alignment: const Alignment(0.2, 0.46),
      filterQuality: FilterQuality.medium,
    );
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
      child: SizedBox(
        // Выше делать нельзя: в окне 1280x900 первый ряд обложек уходит
        // под нижний край, и полка перестаёт читаться с одного взгляда.
        height: 238,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            // Волосяной золотой кант: он отделяет кадр от корпуса, не
            // споря с самой картинкой.
            border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: colors.isDark ? 34 : 12,
                offset: Offset(0, colors.isDark ? 14 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: LayoutBuilder(
              builder: (context, box) {
                // Надпись занимает долю кадра, а не 452 точки: на
                // широкоформатном окне фиксированный блок оставлял
                // название обрезанным посреди пустого кадра.
                final textWidth = (box.maxWidth * 0.44).clamp(320.0, 760.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    HeroSweep(
                      enabled: sweepEnabled,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (coverPath == null)
                            fallback
                          else
                            Image.file(
                              File(coverPath),
                              key: const ValueKey('featured-game-background'),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (context, error, stackTrace) =>
                                  fallback,
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
                          // Второе затемнение снизу: у надписи должна быть
                          // подложка независимо от того, что на картинке.
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.heroShadeMiddle,
                                  AppColors.heroShadeClear,
                                ],
                                stops: [0, 0.62],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 28,
                      top: 24,
                      bottom: 24,
                      width: textWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 1.5,
                                color: AppColors.heroEyebrow,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  L
                                      .of(context)
                                      .conceptFeaturedContinue(
                                        game.lastPlayed == null
                                            ? L.of(context).featuredReady
                                            : L.of(context).featuredRecent,
                                      )
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.heroEyebrow,
                                    fontFamily: EvaporateTheme.monoFontFamily,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            game.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.coverText,
                              fontFamily: EvaporateTheme.displayFontFamily,
                              // Крупнее не влезает: под названием стоят
                              // описание в две строки и ряд клавиш, и в кадре
                              // высотой 238 им нужно место.
                              fontSize: 32,
                              height: 1.04,
                              fontWeight: FontWeight.w800,
                              // Разряд положительный: у широкого шрифта
                              // прижатые заглавные слипаются.
                              letterSpacing: 0.6,
                              shadows: [
                                Shadow(
                                  blurRadius: 18,
                                  color: AppColors.coverTextShadow,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            game.description?.trim().isNotEmpty == true
                                ? game.description!
                                : L.of(context).featuredFallbackDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.heroBody,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              LauncherActionButton(
                                onPressed: playable ? onPrimary : null,
                                icon:
                                    game.status == GameStatus.notInstalled ||
                                        game.status == GameStatus.error
                                    ? Icons.download_rounded
                                    : Icons.play_arrow_rounded,
                                label: _primaryLabel(context, game),
                              ),
                              const SizedBox(width: 9),
                              OutlinedButton(
                                onPressed: onOpen,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.coverText,
                                  side: BorderSide(
                                    color: AppColors.coverText.withValues(
                                      alpha: 0.34,
                                    ),
                                  ),
                                  minimumSize: const Size(112, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      EvaporateTheme.radiusControl,
                                    ),
                                  ),
                                ),
                                child: Text(L.of(context).openGame),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 22,
                      bottom: 22,
                      child: _PlaytimeReadout(game: game),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _primaryLabel(BuildContext context, Game game) =>
      switch (game.status) {
        GameStatus.running => L.of(context).stop,
        GameStatus.downloading => L.of(context).pause,
        GameStatus.paused => L.of(context).resume,
        GameStatus.installed => L.of(context).play,
        GameStatus.notInstalled || GameStatus.error => L.of(context).download,
      };
}

/// Наигранное время — показание прибора, а не подпись: моно, крупно и с
/// табличными цифрами, чтобы при смене числа ничего не дёргалось.
class _PlaytimeReadout extends StatelessWidget {
  const _PlaytimeReadout({required this.game});

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
          style: TextStyle(
            color: AppColors.coverText.withValues(alpha: 0.56),
            fontFamily: EvaporateTheme.monoFontFamily,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          formatDurationLabel(L.of(context), game.playtime),
          style: const TextStyle(
            color: AppColors.coverText,
            fontFamily: EvaporateTheme.monoFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
