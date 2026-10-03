import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../../services/metadata/release_name.dart';
import '../../labels.dart';
import '../../library/featured/featured_art.dart';
import '../../library/primary_action.dart';
import '../art/key_art.dart';
import '../design/theme.dart';
import '../library/ev_hero.dart';
import '../library/hero_state.dart';
import '../library/library_layout.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';

/// Крупный кадр прототипа на данных и действиях выбранной игры.
///
/// Демонстрационные стадии установки и точки сохранения сюда не попадают:
/// состояние задаёт игра, показания — связанная задача движка.
class EvLibraryHero extends StatelessWidget {
  const EvLibraryHero({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
    required this.sweepEnabled,
    required this.shotsEnabled,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  final bool sweepEnabled;
  final bool shotsEnabled;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.launchKey(game.id)),
    );
    final action = primaryActionFor(game);
    final enabled =
        canDoPrimaryAction(game) && !(busy && action == PrimaryAction.play);
    final title = ReleaseName.clean(game.title);
    final layout = EvLibraryLayout.of(MediaQuery.sizeOf(context));
    final content = EvHeroContent(
      eyebrow: l.featuredContinue(
        game.play.lastPlayed == null ? l.featuredReady : l.featuredRecent,
      ),
      blurb: game.details.description ?? '',
      chips: canDoPrimaryAction(game)
          ? [
              (gameStatusLabel(l, game.status), true),
              if (game.sizeBytes > 0) (bytesLabel(l, game.sizeBytes), false),
              if (game.play.playtime > Duration.zero)
                (l.playtime(formatDurationLabel(l, game.play.playtime)), false),
            ]
          : [],
      // Высокая строка под клавишей прячет описание на низком окне.
      note: !canDoPrimaryAction(game)
          ? EvHeroNote(
              action == PrimaryAction.play
                  ? l.featuredNoExecutable
                  : l.featuredNoSource,
              icon: EvIcons.info,
            )
          : null,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 16),
      child: EvHero(
        key: ValueKey(game.id),
        layout: layout,
        palette: EvCoverPalette.ash,
        seed: _seed(game.id),
        title: title.isEmpty ? game.title : title,
        content: content,
        art: game.details.coverPath != null || game.details.shotPaths.isNotEmpty
            ? FeaturedArt(
                game: game,
                compact: false,
                sweep: sweepEnabled,
                shots: shotsEnabled,
              )
            : null,
        actions: (context, height, onCharge) => [
          EvPlayButton(
            key: ValueKey(action),
            label: primaryActionLabel(l, action),
            icon: _icon(action),
            requireHold: action == PrimaryAction.play,
            caption: action == PrimaryAction.play
                ? l.holdToLaunchCaption
                : null,
            holdSemantics: l.holdToLaunchHint,
            cool:
                action == PrimaryAction.download ||
                action == PrimaryAction.pause ||
                action == PrimaryAction.resume,
            height: height,
            onLaunch: enabled ? onPrimary : null,
            onCharge: onCharge,
          ),
          EvGhostButton(
            label: l.openGame,
            icon: EvIcons.info,
            height: height,
            grouped: true,
            onPressed: onOpen,
          ),
          if (task != null && !task.isFinished)
            SizedBox(
              width: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(task.progress * 100).round()} %',
                    style: context.ev.text.data,
                  ),
                  const SizedBox(height: 8),
                  EvBar(task.progress),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _icon(PrimaryAction action) => switch (action) {
    PrimaryAction.play || PrimaryAction.resume => EvIcons.play,
    PrimaryAction.stop => EvIcons.power,
    PrimaryAction.pause => EvIcons.pause,
    PrimaryAction.download => EvIcons.download,
  };

  /// Стабильный рисунок обложки между запусками приложения.
  static int _seed(String id) {
    var seed = 0;
    for (final code in id.codeUnits) {
      seed = ((seed * 31) + code) & 0x7fffffff;
    }
    return seed;
  }
}
