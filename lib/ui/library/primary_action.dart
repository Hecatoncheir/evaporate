import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../theme.dart';

/// Главное действие игры — одно решение для всех мест, где есть её главная
/// клавиша.
///
/// Мест четыре: кнопка X на геймпаде, крупный кадр библиотеки, подпись у
/// его клавиши и карточка на странице игры. `switch` по состоянию игры
/// стоял в каждом, причём в оболочке и в библиотеке — побайтово один и тот
/// же. Разойдись они на одну ветку, и одна игра получила бы разное главное
/// действие с геймпада, с кадра и со своей страницы; заметить это можно
/// было бы только на четвёртом состоянии из шести.
enum PrimaryAction { play, stop, pause, resume, download }

/// Что делает главная клавиша у игры в этом состоянии.
PrimaryAction primaryActionFor(Game game) => switch (game.status) {
  GameStatus.running => PrimaryAction.stop,
  GameStatus.downloading => PrimaryAction.pause,
  GameStatus.paused => PrimaryAction.resume,
  GameStatus.installed => PrimaryAction.play,
  GameStatus.notInstalled || GameStatus.error => PrimaryAction.download,
};

/// Можно ли на неё нажать.
///
/// Отдельно от [primaryActionFor], а не шестым значением: подпись у
/// недоступной клавиши остаётся своя — «Играть» у игры без выбранного
/// исполняемого файла, — и, слив «нечего делать» с действием, мы получили
/// бы клавишу без слова на ней.
bool canDoPrimaryAction(Game game) {
  switch (primaryActionFor(game)) {
    case PrimaryAction.play:
      return game.canLaunch;
    case PrimaryAction.download:
      final source = game.download.source;
      return source != null && source.kind != GameSourceKind.localFolder;
    case PrimaryAction.stop:
    case PrimaryAction.pause:
    case PrimaryAction.resume:
      return true;
  }
}

/// Подпись клавиши.
String primaryActionLabel(L l, PrimaryAction action) => switch (action) {
  PrimaryAction.play => l.play,
  PrimaryAction.stop => l.stop,
  PrimaryAction.pause => l.pause,
  PrimaryAction.resume => l.resume,
  PrimaryAction.download => l.download,
};

/// Значок клавиши.
IconData primaryActionIcon(PrimaryAction action) => switch (action) {
  PrimaryAction.play || PrimaryAction.resume => Icons.play_arrow_rounded,
  PrimaryAction.stop => Icons.stop_circle_outlined,
  PrimaryAction.pause => Icons.pause_rounded,
  PrimaryAction.download => Icons.download_rounded,
};

/// Тон клавиши: запуск и остановка игры горят огнём главного действия, а
/// всё, что про загрузку, — холодным цветом данных. Иначе «Скачать» и
/// «Играть» выглядели бы одной клавишей с разными словами.
LauncherTone primaryActionTone(PrimaryAction action) => switch (action) {
  PrimaryAction.play || PrimaryAction.stop => LauncherTone.launch,
  PrimaryAction.download ||
  PrimaryAction.pause ||
  PrimaryAction.resume => LauncherTone.download,
};

/// Делает то, что написано на клавише.
///
/// Недоступное действие молча не делает ничего: сюда приходят и нажатия с
/// геймпада, где клавишу нельзя погасить.
void dispatchPrimaryAction(BuildContext context, Game game) {
  if (!canDoPrimaryAction(game)) return;

  final library = context.read<LibraryBloc>();
  final downloads = context.read<DownloadsBloc>();
  switch (primaryActionFor(game)) {
    case PrimaryAction.stop:
      library.add(GameStopRequested(game));
    case PrimaryAction.pause:
      downloads.add(DownloadPauseRequested(game));
    case PrimaryAction.resume:
      downloads.add(DownloadResumeRequested(game));
    case PrimaryAction.play:
      library.add(GameLaunchRequested(game));
    case PrimaryAction.download:
      downloads.add(
        DownloadRequested(game: game, source: game.download.source!),
      );
  }
}
