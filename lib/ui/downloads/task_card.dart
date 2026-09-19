import 'package:flutter/material.dart';

import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'download_activity.dart';
import 'download_history_scope.dart';
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
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskHeader(task: task, game: game),
          const SizedBox(height: 14),
          DownloadHistoryScope(
            key: ValueKey(task.id),
            task: task,
            child: DownloadActivity(task: task),
          ),
          const SizedBox(height: 12),
          TaskStats(task: task),
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
}
