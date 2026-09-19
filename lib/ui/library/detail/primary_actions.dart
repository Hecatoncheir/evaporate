import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../primary_action.dart';
import 'download_control_actions.dart';
import 'download_start_actions.dart';
import 'play_actions.dart';
import 'running_game_actions.dart';

/// Действия над самой игрой — левая половина ряда на странице игры.
///
/// Что делает главная клавиша и можно ли на неё нажать, решает общий
/// `primary_action.dart`: то же решение принимают кнопка X на геймпаде и
/// крупный кадр библиотеки. Здесь остаётся только выбрать, какие соседи у
/// клавиши, — у каждой ветки они свои и живут своим виджетом.
class PrimaryActions extends StatelessWidget {
  const PrimaryActions({super.key, required this.game, required this.task});

  final Game game;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.launchKey(game.id)),
    );
    final action = primaryActionFor(game);
    // Занятость гасит только запуск: пауза и отмена нужны и во время работы.
    final enabled =
        canDoPrimaryAction(game) && !(busy && action == PrimaryAction.play);
    final onPressed = enabled
        ? () => dispatchPrimaryAction(context, game)
        : null;
    final label = primaryActionLabel(L.of(context), action);
    final icon = primaryActionIcon(action);

    return switch (action) {
      PrimaryAction.stop => RunningGameActions(
        label: label,
        icon: icon,
        onPressed: onPressed,
      ),
      PrimaryAction.pause || PrimaryAction.resume => DownloadControlActions(
        game: game,
        task: task,
        label: label,
        icon: icon,
        onPressed: onPressed,
      ),
      PrimaryAction.play => PlayActions(
        game: game,
        label: label,
        onPressed: onPressed,
      ),
      PrimaryAction.download => DownloadStartActions(
        game: game,
        label: label,
        icon: icon,
        onPressed: onPressed,
      ),
    };
  }
}
