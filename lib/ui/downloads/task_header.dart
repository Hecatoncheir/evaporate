import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import 'task_actions.dart';

/// Название, состояние задачи и клавиши над карточкой.
class TaskHeader extends StatelessWidget {
  const TaskHeader({super.key, required this.task, required this.game});

  final DownloadTask task;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            game?.title ?? task.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.subtitle,
          ),
        ),
        // Названия релизов длинные и обрезаются по месту: без просвета
        // многоточие упиралось бы прямо в состояние.
        const SizedBox(width: EvaporateSpacing.field),
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
        if (game case final game?) ...[
          const SizedBox(width: EvaporateSpacing.gap),
          TaskActions(task: task, game: game),
        ],
      ],
    );
  }
}
