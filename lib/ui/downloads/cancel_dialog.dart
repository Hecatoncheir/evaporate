import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
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
/// Спросить и, если человек согласился, снять загрузку игры.
///
/// Клавиш отмены три — на карточке задачи, в очереди и на странице игры, —
/// и каждая прежде выписывала этот поток сама. Слова у них свои (в очереди
/// ничего не качается прямо сейчас, и обещать «задача будет снята» было бы
/// не про то), а ход один.
Future<void> cancelDownload(
  BuildContext context, {
  required Game game,
  required DownloadTask? task,
  required String title,
  required String message,
  required String confirmLabel,
  required IconData confirmIcon,
}) async {
  final downloads = context.read<DownloadsBloc>();
  final choice = await _ask(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    confirmIcon: confirmIcon,
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

Future<CancelChoice?> _ask(
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
        style: context.text.prose,
      ),
      actions: [
        // Значки здесь не украшение: три ответа подряд различаются одними
        // словами, а слова у них похожи — «Удалить» и «Удалить совсем».
        // Глазу нужна зацепка помимо чтения.
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(L.of(context).keepDownload),
        ),
        // Только когда стирать и правда есть что: у задачи, не начавшей
        // качать, выбор «вместе с файлами» — предложение ни о чём.
        if (hasDownloadedFiles(task))
          TextButton.icon(
            onPressed: () => Navigator.pop(context, CancelChoice.withFiles),
            style: context.buttons.dangerText,
            icon: const Icon(
              Icons.delete_forever_rounded,
              size: EvaporateIconSize.panel,
            ),
            label: Text(L.of(context).cancelWithFiles),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, CancelChoice.task),
          icon: Icon(confirmIcon, size: EvaporateIconSize.panel),
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
