import 'package:flutter/material.dart';

import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../effects/portal/portal_sparks.dart';
import 'cover_face.dart';

/// Корпус плитки: искры по краю, ореол выбранной, тень, скруглённый вырез
/// и пропорции обложки.
///
/// Искры лежат снаружи выреза: увеличенная под фокусом обложка закрыла бы
/// самые яркие из них у кромки. Вырез — угол панели, и по тому же углу
/// считается кромка искр (`PortalOutline.corner`): при разных углах между
/// обложкой и искрами оставался бы тёмный шов.
class CoverFrame extends StatelessWidget {
  const CoverFrame({
    super.key,
    required this.game,
    required this.task,
    required this.selected,
    required this.dropsEnabled,
    required this.portalEnabled,
    this.aspectRatio = 2 / 3,
    this.face,
  });

  final Game game;
  final DownloadTask? task;
  final bool selected;
  final bool dropsEnabled;

  /// Искры по краю выбранной обложки.
  final bool portalEnabled;

  /// Пропорции выреза: у сетки — обложка Steam 2:3, у полки прототипа —
  /// карточка 3:4, и обложка Steam в ней обрезается по высоте.
  final double aspectRatio;

  /// Лицо обложки вместо обычного (картинка, ход загрузки, значок
  /// состояния): у полки прототипа значки и подпись свои.
  final Widget? face;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);
    // Ореол выбранной — снаружи искр, а не рядом с тенью: искры рисуются
    // первым слоем под обложкой, и тень внутри легла бы поверх них. Снаружи
    // украшение красится раньше всего, что в нём, — ореол под искрами.
    // Приглушён долей от своей же прозрачности: днём цвет ореола пуст, и
    // ступень поверх него дала бы тёмное пятно вместо ничего.
    final glow = context.colors.glow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          if (selected)
            BoxShadow(
              color: glow.withValues(alpha: glow.a * EvaporateAlpha.ghost),
              blurRadius: HardwareSurfaceTheme.of(context).tileGlowBlur,
            ),
        ],
      ),
      child: PortalSparks(
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
              aspectRatio: aspectRatio,
              child:
                  face ??
                  CoverFace(
                    game: game,
                    task: task,
                    selected: selected,
                    dropsEnabled: dropsEnabled,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
