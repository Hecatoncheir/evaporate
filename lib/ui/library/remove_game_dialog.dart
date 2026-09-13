import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../theme.dart';

/// Что человек выбрал, убирая игру.
enum RemoveChoice {
  /// Убрать из библиотеки, файлы на диске оставить.
  libraryOnly,

  /// Убрать и стереть папку установки.
  withFiles,
}

/// Спрашивает перед удалением игры из библиотеки.
///
/// Один диалог на все места, откуда игру убирают: со страницы игры и из
/// списка «Можно скачать» на загрузках. Спрашивают об одном и том же, и
/// расходиться словам незачем.
///
/// «Вместе с файлами» предлагают, только когда папка установки и правда
/// есть: у игры, которую ещё не качали, её нет вовсе, и выбор был бы ни о
/// чём. Снимки сохранений уходят в любом случае — об этом сказано в самом
/// вопросе, потому что вернуть их будет нечем.
Future<RemoveChoice?> askRemoveGame(BuildContext context, Game game) {
  final dir = game.installDir;
  final hasFiles = dir != null && Directory(dir).existsSync();

  return showDialog<RemoveChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(L.of(context).removeQuestion(game.title)),
      content: Text(
        hasFiles
            ? '${L.of(context).removeSnapshotsNote}\n\n'
                  '${L.of(context).removeFilesNote(dir)}'
            : L.of(context).removeSnapshotsNote,
        style: const TextStyle(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
        if (hasFiles)
          TextButton(
            onPressed: () => Navigator.pop(context, RemoveChoice.withFiles),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: Text(L.of(context).removeWithFiles),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, RemoveChoice.libraryOnly),
          child: Text(L.of(context).removeFromLibrary),
        ),
      ],
    ),
  );
}
