import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../theme.dart';

/// Что человек выбрал, снимая загрузку.
enum CancelChoice {
  /// Снять задачу, скачанное оставить на диске.
  task,

  /// Снять задачу и стереть скачанное.
  withFiles,
}

/// Спрашивает перед снятием загрузки.
///
/// Три ответа, а не два. «Оставить» отдельным словом, потому что рядом
/// стоит «Отменить»: две клавиши, читающиеся как одно и то же, — худший
/// вид вопроса, особенно когда одна из них необратима.
///
/// «Удалить совсем вместе с файлами» набрано тревожным цветом и стоит
/// **не** главной клавишей: снятая задача оставляет скачанное на диске, и
/// это правильное умолчание — вернуться к нему можно, к стёртому нельзя.
Future<CancelChoice?> askCancel(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required DownloadTask task,
}) {
  return showDialog<CancelChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        hasDownloadedFiles(task)
            ? '$message\n\n${L.of(context).cancelFilesNote}'
            : message,
        style: const TextStyle(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).keepDownload),
        ),
        // Только когда стирать и правда есть что: у задачи, не начавшей
        // качать, выбор «вместе с файлами» — предложение ни о чём.
        if (hasDownloadedFiles(task))
          TextButton(
            onPressed: () => Navigator.pop(context, CancelChoice.withFiles),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: Text(L.of(context).cancelWithFiles),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, CancelChoice.task),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Есть ли что стирать: задача могла ещё ни байта не скачать.
bool hasDownloadedFiles(DownloadTask task) =>
    task.completedBytes > 0 || task.files.isNotEmpty;
