import 'package:flutter/material.dart';

import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'download_activity.dart';
import 'task_header.dart';
import 'task_stats.dart';

/// Карточка идущей загрузки: заголовок с клавишами, ход с графиком и
/// показания под ним.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.game});

  final DownloadTask task;
  final Game? game;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: EvaporateSpacing.field),
    child: Padding(
      padding: const EdgeInsets.all(EvaporateSpacing.panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskHeader(task: task, game: game),
          const SizedBox(height: EvaporateSpacing.block),
          DownloadActivity(task: task),
          const SizedBox(height: EvaporateSpacing.field),
          TaskStats(task: task),
          if (task.errorMessage != null) ...[
            const SizedBox(height: EvaporateSpacing.cluster),
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
}
