import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../labels.dart';
import '../effects/cover_drops.dart';
import '../effects/foil/foil_surface.dart';
import 'cover_art.dart';
import 'cover_progress_strip.dart';
import 'cover_status_badge.dart';

/// Лицо плитки: сама обложка, а поверх неё ход загрузки или значок
/// состояния.
class CoverFace extends StatelessWidget {
  const CoverFace({
    super.key,
    required this.game,
    required this.task,
    required this.selected,
    required this.dropsEnabled,
  });

  final Game game;

  /// Задача загрузки этой игры, если она есть.
  final DownloadTask? task;

  final bool selected;

  /// Капли на обложке выбранной игры.
  final bool dropsEnabled;

  bool get _running => task != null && !task!.isFinished;

  /// Что услышит человек, дошедший до плитки: название, состояние и — если
  /// игра качается — насколько.
  String _spokenLabel(BuildContext context) {
    final l = L.of(context);
    final parts = <String>[game.title, gameStatusLabel(l, game.status)];
    if (_running) parts.add(percentLabel(l, task!.progress));
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _spokenLabel(context),
      // Плитка открывает игру, и сказать об этом надо явно: сама по себе
      // она объявляется просто выделяемой областью.
      button: true,
      selected: selected,
      // Значок состояния и название на подложке говорят то же самое: с
      // ними одна плитка звучала бы тремя объявлениями.
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FoilSurface(
            // Капли — только у выбранной: они стоят кадров, а вся сетка
            // под дождём читалась бы хуже, чем одна плитка.
            child: CoverDrops(
              enabled: selected && dropsEnabled,
              coverPath: game.details.coverPath,
              child: CoverArt(game: game, underStrip: _running),
            ),
          ),
          if (_running && task != null) CoverProgressStrip(task: task!),
          if (!_running) CoverStatusBadge(game: game),
        ],
      ),
    );
  }
}
