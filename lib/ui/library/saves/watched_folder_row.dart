import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/saves/save_path_finder.dart';
import '../../theme.dart';

/// Одна подсказка: путь, сколько файлов в нём изменилось, и «Добавить».
class WatchedFolderRow extends StatelessWidget {
  const WatchedFolderRow({super.key, required this.game, required this.hint});

  final Game game;
  final SavePathSuggestion hint;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint.template,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.path.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // У наблюдения число говорит «столько изменилось за игру»,
                  // у поиска по имени — просто «столько лежит».
                  hint.origin == SavePathOrigin.watch
                      ? l.watchedFilesChanged(hint.fileCount)
                      : l.guessedFilesCount(hint.fileCount),
                  style: context.text.small.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => context.read<SavesBloc>().add(
              SaveHintsAccepted(game: game, suggestions: [hint]),
            ),
            child: Text(l.add),
          ),
        ],
      ),
    );
  }
}
