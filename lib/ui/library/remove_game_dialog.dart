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
Future<RemoveChoice?> askRemoveGame(BuildContext context, Game game) {
  return showDialog<RemoveChoice>(
    context: context,
    builder: (context) => RemoveGameDialog(game: game),
  );
}

/// Вопрос об удалении игры.
///
/// «Вместе с файлами» предлагают, только когда папка установки и правда
/// есть: у игры, которую ещё не качали, её нет вовсе, и выбор был бы ни о
/// чём. Снимки сохранений уходят в любом случае — об этом сказано в самом
/// вопросе, потому что вернуть их будет нечем.
class RemoveGameDialog extends StatelessWidget {
  const RemoveGameDialog({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dir = game.installDir;
    final hasFiles = dir != null && Directory(dir).existsSync();

    return AlertDialog(
      title: Text(l.removeQuestion(game.title)),
      content: Text(
        hasFiles
            ? '${l.removeSnapshotsNote}\n\n${l.removeFilesNote(dir)}'
            : l.removeSnapshotsNote,
        style: context.text.prose,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        if (hasFiles)
          TextButton(
            onPressed: () => Navigator.pop(context, RemoveChoice.withFiles),
            style: context.buttons.dangerText,
            child: Text(l.removeWithFiles),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, RemoveChoice.libraryOnly),
          child: Text(l.removeFromLibrary),
        ),
      ],
    );
  }
}
