import 'package:flutter/material.dart';

import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../effects/portal_sparks.dart';
import 'cover_face.dart';

/// Корпус плитки: искры по краю, тень, скруглённый вырез и пропорции
/// обложки.
///
/// Искры лежат снаружи выреза: увеличенная под фокусом обложка закрыла бы
/// самые яркие из них у кромки.
class CoverFrame extends StatelessWidget {
  const CoverFrame({
    super.key,
    required this.game,
    required this.task,
    required this.selected,
    required this.dropsEnabled,
    required this.portalEnabled,
  });

  final Game game;
  final DownloadTask? task;
  final bool selected;
  final bool dropsEnabled;

  /// Искры по краю выбранной обложки.
  final bool portalEnabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(EvaporateTheme.radiusControl);
    return PortalSparks(
      enabled: selected && portalEnabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              // Тень своя, а не из темы: она отделяет обложку от фона, и в
              // светлой теме нужна не меньше, чем в тёмной.
              color: AppColors.coverShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: CoverFace(
              game: game,
              task: task,
              selected: selected,
              dropsEnabled: dropsEnabled,
            ),
          ),
        ),
      ),
    );
  }
}
