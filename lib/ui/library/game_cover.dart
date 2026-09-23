import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import 'cover/cover_frame.dart';
import 'nav_tile.dart';

/// Плитка библиотеки: вертикальная обложка 2:3, как в Steam.
///
/// Обложка тут не украшение, а единственная подпись: сетку читают по
/// картинкам, а не по названиям. Поэтому название показывается только там,
/// где картинки нет, — и во всю плитку, чтобы игру всё равно было видно.
///
/// Открывает игру и выбирает её плитка сама: нажатие и фокус случаются
/// здесь, и везти их наверх колбэками через сетку незачем.
class GameCoverTile extends StatelessWidget {
  const GameCoverTile({
    super.key,
    required this.game,
    required this.selected,
    required this.effects,
    this.focusNode,
  });

  final Game game;

  /// Игра, к которой возвращаются, закрыв её страницу.
  final bool selected;

  /// Облик библиотеки: капли, искры и рамка. Приходит сверху: плитка о
  /// настройках не спрашивает.
  final Appearance effects;

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
    final nav = context.read<NavigationBloc>();
    return MergeSemantics(
      child: NavTile(
        focusNode: focusNode,
        onTap: () => nav.add(GameOpened(game.id)),
        // Фокус восстанавливается на той игре, с которой ушли на её страницу:
        // иначе после «назад» сетка теряла бы место, и искать пришлось бы
        // заново.
        autofocus: selected,
        // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть» должна
        // работать по той игре, на которую смотришь, не заходя внутрь.
        onFocusChange: (has) {
          if (has) nav.add(GameSelected(game.id));
        },
        // Рамка живёт мимо общего выключателя эффектов: она показывает, где
        // ты в сетке, а не украшает её.
        showFocusBorder: effects.isOn(LibraryEffect.selectionFrame),
        // Контур растёт вместе с фокусом, но остаётся снаружи ClipRRect.
        // Иначе увеличенная обложка закрывает самые яркие искры у кромки.
        child: CoverFrame(
          game: game,
          task: task,
          selected: selected,
          dropsEnabled: effects.shows(LibraryEffect.drops),
          portalEnabled: effects.shows(LibraryEffect.portal),
        ),
      ),
    );
  }
}
