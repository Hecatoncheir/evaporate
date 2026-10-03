import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/app_settings.dart';
import '../../../models/game.dart';
import '../../../models/library_effect.dart';
import '../../library/cover/cover_frame.dart';
import '../../library/effects/cover_drops.dart';
import '../../library/effects/foil/foil_card.dart';
import '../../library/effects/foil/foil_surface.dart';
import '../../theme.dart';
import '../art/ev_art.dart';
import '../art/key_art.dart';

/// Обложка карточки полки с украшениями приложения: фольга и наклон
/// (`FoilCard`) вокруг рамки с искрами и ореолом (`CoverFrame`), внутри
/// которой капли по обложке.
///
/// Картинка — настоящая обложка игры, а под ней рисованная обложка
/// прототипа: пока файл грузится или если его нет, карточка не пустая.
/// Капли идут только по файлу — шейдеру нужна сама картинка; искры,
/// фольга и наклон горят на любой.
///
/// Тема приложения — местная: украшения берут цвета, тени и облик искр из
/// её расширений, а у прототипа тема своя.
class EvEffectCover extends StatelessWidget {
  const EvEffectCover({
    super.key,
    required this.game,
    required this.active,
    required this.palette,
    required this.seed,
    this.effects,
  });

  final Game game;

  /// Карточка горит — под курсором или в фокусе.
  final bool active;

  /// Рисованная обложка прототипа на случай, когда файла нет.
  final EvCoverPalette palette;
  final int seed;

  /// Настройки настоящей игры; у автономного прототипа их нет.
  final Appearance? effects;

  static final _theme = EvaporateTheme.dark();

  @override
  Widget build(BuildContext context) {
    final path = game.details.coverPath;
    final appearance = effects;
    final art = Stack(
      fit: StackFit.expand,
      children: [
        EvCover(palette: palette, seed: seed),
        if (path != null)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
      ],
    );
    return Theme(
      data: appearance == null ? _theme : Theme.of(context),
      child: FoilCard(
        active: active,
        enabled: appearance?.libraryEffects ?? true,
        foilEnabled: appearance?.isOn(LibraryEffect.foil) ?? true,
        tiltEnabled: appearance?.isOn(LibraryEffect.cardTilt) ?? true,
        distortionEnabled:
            appearance?.isOn(LibraryEffect.liquidDistortion) ?? true,
        child: CoverFrame(
          game: game,
          task: null,
          selected: active,
          dropsEnabled: appearance?.shows(LibraryEffect.drops) ?? true,
          portalEnabled: appearance?.shows(LibraryEffect.portal) ?? true,
          aspectRatio: 3 / 4,
          face: FoilSurface(
            child: CoverDrops(
              enabled:
                  active && (appearance?.shows(LibraryEffect.drops) ?? true),
              coverPath: path,
              child: art,
            ),
          ),
        ),
      ),
    );
  }
}
