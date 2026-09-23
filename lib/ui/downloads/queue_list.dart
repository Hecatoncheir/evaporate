import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../models/download_task.dart';
import 'queued_card.dart';

/// Очередь с перестановкой перетаскиванием.
class QueueList extends StatelessWidget {
  const QueueList({super.key, required this.queued, required this.library});

  final List<DownloadTask> queued;
  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: queued.length,
      // onReorderItem уже учитывает изъятие перемещаемого элемента —
      // ровно в том счёте, в каком место ищет `_reorder`.
      onReorderItem: (from, to) => _reorder(context, from, to),
      itemBuilder: (context, index) {
        final task = queued[index];
        return ReorderableDragStartListener(
          key: ValueKey(task.id),
          index: index,
          child: QueuedCard(
            task: task,
            position: index + 1,
            game: library.gameForTask(task.id),
            onMoveUp: index > 0
                ? () => _reorder(context, index, index - 1)
                : null,
            onMoveDown: index < queued.length - 1
                ? () => _reorder(context, index, index + 1)
                : null,
          ),
        );
      },
    );
  }

  /// Переносит задачу с места [from] на место [to], считанное в очереди
  /// уже без неё. И перетаскивание, и клавиши «выше/ниже» называют движку
  /// соседа, а не место: место у движка своё, в общем порядке всех задач,
  /// и знать его устройство виджету незачем.
  void _reorder(BuildContext context, int from, int to) {
    final moved = queued[from];
    final rest = [...queued]..removeAt(from);
    final before = to < rest.length ? rest[to].id : null;
    context.read<DownloadsBloc>().add(
      DownloadReordered(id: moved.id, beforeId: before),
    );
  }
}
