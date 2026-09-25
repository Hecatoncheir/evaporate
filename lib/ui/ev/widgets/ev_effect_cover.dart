import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/game.dart';
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
  });

  final Game game;

  /// Карточка горит — под курсором или в фокусе.
  final bool active;

  /// Рисованная обложка прототипа на случай, когда файла нет.
  final EvCoverPalette palette;
  final int seed;

  static final _theme = EvaporateTheme.dark();

  @override
  Widget build(BuildContext context) {
    final path = game.details.coverPath;
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
      data: _theme,
      child: FoilCard(
        active: active,
        enabled: true,
        child: CoverFrame(
          game: game,
          task: null,
          selected: active,
          dropsEnabled: true,
          portalEnabled: true,
          aspectRatio: 3 / 4,
          face: FoilSurface(
            child: CoverDrops(enabled: active, coverPath: path, child: art),
          ),
        ),
      ),
    );
  }
}
