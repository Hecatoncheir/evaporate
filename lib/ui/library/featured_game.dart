import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/launcher_action_button.dart';
import 'hero_sweep.dart';
import 'primary_action.dart';
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
    final colors = context.colors;
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);

    final (top, bottom) = compact ? (6.0, 8.0) : (8.0, 10.0);
    return Padding(
      padding: EvaporateLayout.inset(top: top, bottom: bottom),
      child: SizedBox(
        // Выше полного кадра делать нельзя: в окне 1280x900 первый ряд
        // обложек уходит под нижний край, и полка перестаёт читаться с
        // одного взгляда.
        height: compact ? 128 : 238,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            // Волосяной золотой кант: он отделяет кадр от корпуса, не
            // споря с самой картинкой.
            border: Border.all(
              color: colors.primary.withValues(alpha: EvaporateAlpha.soft),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: HardwareSurfaceTheme.of(context).frameShadowBlur,
                offset: Offset(
                  0,
                  HardwareSurfaceTheme.of(context).frameShadowDrop,
                ),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                fit: StackFit.expand,
                children: [
                  _Art(
                    game: game,
                    compact: compact,
                    sweep: sweepEnabled,
                    shots: shotsEnabled,
                  ),
                  if (compact)
                    _CompactContent(
                      game: game,
                      onOpen: onOpen,
                      onPrimary: onPrimary,
                    )
                  else
                    ..._full(context, box.maxWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _full(BuildContext context, double width) {
    // Надпись занимает долю кадра, а не фиксированные 452 точки: на
    // широкоформатном окне такой блок оставлял название обрезанным посреди
    // пустого кадра.
    final textWidth = (width * 0.44).clamp(320.0, 760.0);
    return [
      Positioned(
        left: EvaporateLayout.gutter,
        top: 24,
        bottom: 24,
        width: textWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow(game: game),
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
            const SizedBox(height: 10),
            Text(
              game.description?.trim().isNotEmpty == true
                  ? game.description!
                  : L.of(context).featuredFallbackDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.note.copyWith(
                color: AppColors.heroBody,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _Actions(game: game, onOpen: onOpen, onPrimary: onPrimary),
          ],
        ),
      ),
      Positioned(right: 22, bottom: 22, child: _PlaytimeReadout(game: game)),
    ];
  }
}

/// Сама картинка с затемнениями и пробегом света.
class _Art extends StatelessWidget {
  const _Art({
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

/// Полоса: название и клавиши в одной строке.
class _CompactContent extends StatelessWidget {
  const _CompactContent({
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 20, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Наигранное время уходит в надстрочную метку: отдельному
              // показанию в полосе места нет, а знать его человек хочет.
              _Eyebrow(game: game, withPlaytime: true),
              const SizedBox(height: 8),
              Text(
                game.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.coverText,
                  fontFamily: EvaporateTheme.displayFontFamily,
                  fontSize: 22,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(blurRadius: 14, color: AppColors.coverTextShadow),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _Actions(game: game, onOpen: onOpen, onPrimary: onPrimary),
      ],
    ),
  );
}

/// Надстрочная метка: чем игра занята и сколько в неё играли.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.game, this.withPlaytime = false});

  final Game game;
  final bool withPlaytime;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    var text = l.conceptFeaturedContinue(
      game.lastPlayed == null ? l.featuredReady : l.featuredRecent,
    );
    if (withPlaytime && game.playtime > Duration.zero) {
      text = '$text · ${formatDurationLabel(l, game.playtime)}';
    }
    return Row(
      children: [
        Container(width: 22, height: 1.5, color: AppColors.heroEyebrow),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.eyebrow.copyWith(color: AppColors.heroEyebrow),
          ),
        ),
      ],
    );
  }
}

/// Главная клавиша и переход на страницу игры.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    // Что делает клавиша, решает общий `primary_action.dart`: то же решение
    // принимают кнопка X на геймпаде и карточка на странице игры. Здесь
    // прежде стоял свой `switch`, и значок в нём был один на все состояния
    // — «Пауза» подписывала клавишу с треугольником «играть».
    final action = primaryActionFor(game);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LauncherActionButton(
          onPressed: canDoPrimaryAction(game) ? onPrimary : null,
          icon: primaryActionIcon(action),
          label: primaryActionLabel(L.of(context), action),
        ),
        const SizedBox(width: 9),
        OutlinedButton(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coverText,
            side: BorderSide(
              color: AppColors.coverText.withValues(alpha: 0.34),
            ),
            minimumSize: const Size(112, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
            ),
          ),
          child: Text(L.of(context).openGame),
        ),
      ],
    );
  }
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
