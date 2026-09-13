import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';

import '../../l10n/app_localizations.dart';

class FeaturedGame extends StatelessWidget {
  const FeaturedGame({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final playable = game.status != GameStatus.installed || game.canLaunch;
    final coverPath = game.coverPath;
    final fallback = Image.asset(
      'assets/branding/orbit_fall_hero.png',
      key: const ValueKey('featured-game-background-fallback'),
      fit: BoxFit.cover,
      alignment: const Alignment(0.2, 0.46),
      filterQuality: FilterQuality.medium,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: SizedBox(
        height: 238,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                  errorBuilder: (context, error, stackTrace) => fallback,
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
                    stops: [0, 0.48, 0.82],
                  ),
                ),
              ),
              Positioned(
                left: 26,
                top: 22,
                bottom: 22,
                width: 430,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L
                          .of(context)
                          .conceptFeaturedContinue(
                            game.lastPlayed == null
                                ? L.of(context).featuredReady
                                : L.of(context).featuredRecent,
                          ),
                      style: const TextStyle(
                        color: AppColors.heroEyebrow,
                        fontFamily: EvaporateTheme.monoFontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      game.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.coverText,
                        fontFamily: EvaporateTheme.displayFontFamily,
                        fontSize: 38,
                        height: 0.88,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
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
                        fontSize: 12,
                        height: 1.35,
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
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onOpen,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.coverText,
                            side: BorderSide(
                              color: AppColors.coverText.withValues(
                                alpha: 0.38,
                              ),
                            ),
                            minimumSize: const Size(112, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                right: 20,
                bottom: 18,
                child: Container(
                  width: 198,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.heroPanel,
                    border: Border.all(color: AppColors.coverProgressTrack),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.of(context).inGame,
                        style: TextStyle(
                          color: AppColors.coverText.withValues(alpha: 0.6),
                          fontFamily: EvaporateTheme.monoFontFamily,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDurationLabel(L.of(context), game.playtime),
                        style: const TextStyle(
                          color: AppColors.coverText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
