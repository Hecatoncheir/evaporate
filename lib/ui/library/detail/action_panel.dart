import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../../services/launch/executable_finder.dart';
import '../../downloads/cancel_dialog.dart';
import '../../downloads/download_activity.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../play_button.dart';
import '../primary_action.dart';

/// Главная кнопка карточки плюс прогресс загрузки.
///
/// Занятость приходит из состояния блока: виджету больше не нужен свой
/// флаг и `try/catch` — ошибки показывает общий слушатель в оболочке.
class ActionPanel extends StatelessWidget {
  const ActionPanel({super.key, required this.game, required this.task});

  final Game game;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.launchKey(game.id)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: _buildRow(context, busy)),
            if (task != null && task!.state != DownloadState.complete) ...[
              const SizedBox(height: 16),
              // Без графика: он уехал подложкой под заголовок страницы, и
              // рисовать его здесь второй раз незачем. История у них общая
              // — её держит `DownloadHistoryScope` вокруг всей страницы.
              DownloadActivity(task: task!, showChart: false),
              const SizedBox(height: 10),
              DownloadSummary(task: task!),
            ],
            if (game.status == GameStatus.error && game.lastError != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: context.colors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.lastError!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.danger,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ряд действий: слева — то, что делают с самой игрой, справа — то, что
  /// делают с её ярлыком в Steam.
  List<Widget> _buildRow(BuildContext context, bool busy) {
    return [
      ..._primaryActions(context, busy),
      // Правая половина забирает всё оставшееся место и прижимает клавиши
      // к краю. Распорка тут не годится, хотя напрашивается: она делила бы
      // свободное место с ними поровну, и подписи переносились бы на
      // вторую строку при живом пустом месте слева.
      //
      // Wrap внутри — на случай, когда места и правда мало: подписи у
      // Steam длинные, и в узком окне две клавиши рядом с «Играть»
      // переполнили бы ряд полосатой лентой.
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (game.canLaunch) _SteamShortcutButton(game: game),
              _SteamLookupButton(game: game),
            ],
          ),
        ),
      ),
    ];
  }

  /// Действия над самой игрой — левая половина ряда.
  ///
  /// Что делает главная клавиша и можно ли на неё нажать, решает общий
  /// `primary_action.dart`: то же решение принимают кнопка X на геймпаде и
  /// крупный кадр библиотеки. Здесь остаётся только то, чего у них нет —
  /// соседние клавиши и пояснения.
  List<Widget> _primaryActions(BuildContext context, bool busy) {
    final l = L.of(context);
    final action = primaryActionFor(game);
    // Занятость гасит только запуск: пауза и отмена нужны и во время работы.
    final enabled =
        canDoPrimaryAction(game) && !(busy && action == PrimaryAction.play);
    final onPressed = enabled
        ? () => dispatchPrimaryAction(context, game)
        : null;
    final label = primaryActionLabel(l, action);

    switch (action) {
      case PrimaryAction.stop:
        return [
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(primaryActionIcon(action), size: 18),
            label: Text(label),
          ),
          const SizedBox(width: 14),
          Text(
            l.gameRunning,
            style: TextStyle(color: context.colors.accent, fontSize: 13),
          ),
        ];

      case PrimaryAction.pause:
      case PrimaryAction.resume:
        return [
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(primaryActionIcon(action), size: 18),
            label: Text(label),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _cancelDownload(context),
            icon: const Icon(Icons.close, size: 17),
            label: Text(l.cancelDownload),
          ),
        ];

      case PrimaryAction.play:
        return [
          PlayButton(onPressed: onPressed, label: label),
          // Пояснение гибкое, а не растянутое: справа стоят клавиши Steam, и
          // растяжка отобрала бы у них половину места под пустой текст.
          if (!game.canLaunch) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l.pickExecutableNote,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ];

      case PrimaryAction.download:
        return [
          LauncherActionButton(
            onPressed: onPressed,
            icon: primaryActionIcon(action),
            label: label,
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _pickInstallDir(context),
            icon: const Icon(Icons.folder_outlined, size: 17),
            label: Text(l.setFolder),
          ),
        ];
    }
  }

  /// Тот же вопрос, что на экране загрузок: действие одно и то же, и
  /// спрашивать о нём по-разному в двух местах незачем.
  Future<void> _cancelDownload(BuildContext context) async {
    final downloads = context.read<DownloadsBloc>();
    final choice = await askCancel(
      context,
      title: L.of(context).cancelDownloadQuestion,
      message: L.of(context).cancelDownloadNote,
      confirmLabel: L.of(context).cancelDownloadConfirm,
      confirmIcon: Icons.remove_circle_outline,
      task: task,
    );
    if (choice == null) return;
    downloads.add(
      DownloadCancelRequested(
        game,
        deleteFiles: choice == CancelChoice.withFiles,
      ),
    );
  }

  Future<void> _pickInstallDir(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath();
    if (dir == null) return;

    final candidates = await ExecutableFinder.scan(dir);
    library.add(
      GameUpdated(
        game.copyWith(
          installDir: dir,
          status: GameStatus.installed,
          executablePath:
              game.executablePath ??
              (candidates.isEmpty ? null : candidates.first.path),
        ),
      ),
    );
  }
}

/// «Добавить в Steam» — заводит игру сторонним ярлыком.
class _SteamShortcutButton extends StatelessWidget {
  const _SteamShortcutButton({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamShortcutKey(game.id)),
    );
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () => context.read<LibraryBloc>().add(SteamShortcutRequested(game)),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.library_add_outlined, size: 16),
      label: Text(L.of(context).steamAddAction),
    );
  }
}

/// «Найти в Steam» или «Обновить из Steam» — описание и обложка из каталога.
class _SteamLookupButton extends StatelessWidget {
  const _SteamLookupButton({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamKey(game.id)),
    );
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () => context.read<LibraryBloc>().add(SteamLookupRequested(game)),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.travel_explore, size: 16),
      label: Text(
        game.steamAppId == null
            ? L.of(context).findInSteam
            : L.of(context).refreshFromSteam,
      ),
    );
  }
}

/// Строка под графиком: сколько осталось и с кем обмениваемся.
///
/// Полосу и проценты рисует сам [DownloadActivity] — здесь только то, чего
/// у него нет. Две полосы подряд означали бы, что одна из них лишняя, и
/// человек честно пытался бы понять, чем они различаются.
class DownloadSummary extends StatelessWidget {
  const DownloadSummary({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (task.isMetadata)
            Text(L.of(context).fetchingTorrentMetadata)
          else ...[
            if (task.etaSeconds > 0)
              Text(
                L
                    .of(context)
                    .etaLeft(formatEtaLabel(L.of(context), task.etaSeconds)),
              ),
            Text(L.of(context).peersCount(task.connections)),
            if (task.seeders > 0) Text(L.of(context).seedsCount(task.seeders)),
          ],
        ],
      ),
    );
  }
}
