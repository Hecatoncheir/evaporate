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
      // onReorderItem уже учитывает изъятие перемещаемого элемента,
      // поэтому индекс соседа ищем в списке без него.
      onReorderItem: (oldIndex, newIndex) {
        final moved = queued[oldIndex];
        final rest = [...queued]..removeAt(oldIndex);
        // Называем соседа, а не место: место у движка своё, в общем
        // порядке всех задач, и знать его устройство виджету незачем.
        final target = newIndex < rest.length ? rest[newIndex] : null;
        context.read<DownloadsBloc>().add(
          DownloadReordered(id: moved.id, beforeId: target?.id),
        );
      },
      itemBuilder: (context, index) {
        final task = queued[index];
        return ReorderableDragStartListener(
          key: ValueKey(task.id),
          index: index,
          child: QueuedCard(
            task: task,
            position: index + 1,
            game: library.gameForTask(task.id),
          ),
        );
      },
    );
  }
}
