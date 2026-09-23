import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'cover/cover_frame.dart';
import 'nav_tile.dart';

/// Плитка библиотеки: вертикальная обложка 2:3, как в Steam.
///
/// Обложка тут не украшение, а единственная подпись: сетку читают по
/// картинкам, а не по названиям. Поэтому название показывается только там,
/// где картинки нет, — и во всю плитку, чтобы игру всё равно было видно.
class GameCoverTile extends StatelessWidget {
  const GameCoverTile({
    super.key,
    required this.game,
    required this.selected,
    this.dropsEnabled = false,
    this.portalEnabled = false,
    this.frameEnabled = true,
    required this.onOpen,
    required this.onFocused,
    this.focusNode,
  });

  final Game game;

  /// Игра, к которой возвращаются, закрыв её страницу.
  final bool selected;

  /// Капли на обложке выбранной игры. Приходит сверху вместе с остальными
  /// эффектами: плитка о настройках не спрашивает.
  final bool dropsEnabled;

  /// Искры по краю выбранной обложки.
  final bool portalEnabled;

  /// Рамка вокруг обложки под фокусом. Выключается отдельно от эффектов:
  /// без неё место в сетке показывает только рост обложки.
  final bool frameEnabled;
  final VoidCallback onOpen;
  final VoidCallback onFocused;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    // Сетку читают по картинкам, и текста в плитке с обложкой нет вовсе —
    // экранному диктору объявить было бы нечего. Подпись собирается
    // внутри плитки (CoverFace), а не поверх неё: обёртка с
    // `excludeSemantics` снаружи убирает вместе с лишними подписями и
    // действие нажатия, и плитка перестаёт нажиматься с клавиатуры. А
    // `MergeSemantics` сводит кнопку и подпись в одно объявление — иначе
    // диктор читает их подряд двумя.
    return MergeSemantics(
      child: NavTile(
        focusNode: focusNode,
        onTap: onOpen,
        // Фокус восстанавливается на той игре, с которой ушли на её страницу:
        // иначе после «назад» сетка теряла бы место, и искать пришлось бы
        // заново.
        autofocus: selected,
        onFocusChange: (has) {
          if (has) onFocused();
        },
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: EvaporateTheme.radiusControl,
        borderWidth: 2.5,
        showFocusBorder: frameEnabled,
        focusedScale: 1.06,
        // Контур растёт вместе с фокусом, но остаётся снаружи ClipRRect.
        // Иначе увеличенная обложка закрывает самые яркие искры у кромки.
        child: CoverFrame(
          game: game,
          task: task,
          selected: selected,
          dropsEnabled: dropsEnabled,
          portalEnabled: portalEnabled,
        ),
      ),
    );
  }
}
