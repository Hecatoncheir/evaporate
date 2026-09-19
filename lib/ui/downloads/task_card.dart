import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cancel_dialog.dart';
import 'download_activity.dart';

/// Отмена спрашивает, как и на странице игры.
///
/// Задача снимается насовсем: место в очереди, обмен с пирами и состояние
/// кусков теряются, а игра уходит из «качается» обратно в «не
/// установлена». Файлы при этом остаются, но продолжить с того же места
/// одним нажатием уже нельзя.
Future<void> _cancel(BuildContext context, Game game, DownloadTask task) async {
  final downloads = context.read<DownloadsBloc>();
  final choice = await askCancel(
    context,
    title: L.of(context).cancelDownloadQuestion,
    message: L.of(context).cancelDownloadNote,
    // «Удалить», а не «Отменить»: рядом стоит «Удалить совсем вместе с
    // файлами», и два ответа должны читаться парой, от меньшего к
    // большему. Подсказка на самой клавише остаётся «Отменить» — там, в
    // ряду с паузой, это точное слово.
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

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.game});

  final DownloadTask task;
  final Game? game;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: 14),
          DownloadHistoryScope(
            key: ValueKey(task.id),
            task: task,
            child: DownloadActivity(task: task),
          ),
          const SizedBox(height: 12),
          _stats(context),
          if (task.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              task.errorMessage!,
              style: context.text.caption.copyWith(
                color: context.colors.danger,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  /// Название, состояние задачи и клавиши над ней.
  Widget _header(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            game?.title ?? task.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
        // Названия релизов длинные и обрезаются по месту: без просвета
        // многоточие упиралось бы прямо в состояние.
        const SizedBox(width: 12),
        Text(
          task.isMetadata ? l.stateMetadata : downloadStateLabel(l, task.state),
          style: context.text.caption.copyWith(
            color: task.state == DownloadState.error
                ? context.colors.danger
                : context.colors.textSecondary,
          ),
        ),
        // Клавиши есть только у задачи, за которой стоит игра: чужую
        // раздачу движка ни паузить, ни отменять отсюда нечем.
        if (game != null) ...[
          const SizedBox(width: 8),
          ..._actions(context, game!),
        ],
      ],
    );
  }

  /// Пауза (она же продолжение) и отмена.
  List<Widget> _actions(BuildContext context, Game game) {
    final l = L.of(context);
    final downloads = context.read<DownloadsBloc>();
    final paused = task.state == DownloadState.paused;
    return [
      IconAction(
        onPressed: () => downloads.add(
          paused ? DownloadResumeRequested(game) : DownloadPauseRequested(game),
        ),
        icon: paused ? Icons.play_arrow : Icons.pause,
        tooltip: paused ? l.resume : l.pause,
      ),
      const SizedBox(width: 6),
      IconAction(
        onPressed: () => _cancel(context, game, task),
        icon: Icons.close,
        tooltip: l.cancelDownload,
        danger: true,
      ),
    ];
  }

  /// Показания под графиком: раздающие, пиры, отданное и остаток времени.
  Widget _stats(BuildContext context) {
    final l = L.of(context);
    return DefaultTextStyle(
      style: context.text.captionMuted,
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (task.seeders > 0) Text(l.seedsCount(task.seeders)),
          // Отданное показываем всегда, когда оно есть: раздача — плата за
          // скачанное, и знать свой вклад пользователь вправе.
          if (task.uploadedBytes > 0) ...[
            Text(l.uploadedTotal(formatBytes(task.uploadedBytes))),
            if (task.completedBytes > 0) ...[
              const SizedBox(width: 6),
              Text(l.ratioValue(_ratio)),
            ],
          ],
          Text(l.peersCount(task.connections)),
          if (!task.isMetadata && task.etaSeconds > 0)
            Text(l.etaLeft(formatEtaLabel(l, task.etaSeconds))),
        ],
      ),
    );
  }

  /// Сколько отдано на каждый скачанный байт.
  String get _ratio =>
      (task.uploadedBytes / task.completedBytes).toStringAsFixed(2);
}
