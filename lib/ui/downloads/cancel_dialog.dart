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
  required IconData confirmIcon,
  required DownloadTask? task,
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
        // Значки здесь не украшение: три ответа подряд различаются одними
        // словами, а слова у них похожи — «Удалить» и «Удалить совсем».
        // Глазу нужна зацепка помимо чтения.
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 17),
          label: Text(L.of(context).keepDownload),
        ),
        // Только когда стирать и правда есть что: у задачи, не начавшей
        // качать, выбор «вместе с файлами» — предложение ни о чём.
        if (hasDownloadedFiles(task))
          TextButton.icon(
            onPressed: () => Navigator.pop(context, CancelChoice.withFiles),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(L.of(context).cancelWithFiles),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, CancelChoice.task),
          icon: Icon(confirmIcon, size: 18),
          label: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Есть ли что стирать: задача могла ещё ни байта не скачать, а на странице
/// игры её может не оказаться вовсе.
bool hasDownloadedFiles(DownloadTask? task) =>
    task != null && (task.completedBytes > 0 || task.files.isNotEmpty);
