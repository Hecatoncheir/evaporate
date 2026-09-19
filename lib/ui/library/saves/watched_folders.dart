import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/saves/save_path_finder.dart';
import '../../theme.dart';
import '../../widgets/inset_tile.dart';
import 'watched_folder_row.dart';
import 'watched_folders_actions.dart';

/// Папки, изменившиеся, пока игра работала.
///
/// Показываются отдельно от правил и требуют подтверждения: рядом с сейвами
/// игры пишут логи и кэш, и отличить одно от другого наверняка нельзя. Зато
/// это единственный источник для игр, которых нет в базе путей, — а таких у
/// торрент-лончера половина библиотеки.
class WatchedFolders extends StatelessWidget {
  const WatchedFolders({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final hints = context.select<SavesBloc, List<SavePathSuggestion>>(
      (bloc) => bloc.state.hintsFor(game.id),
    );
    if (hints.isEmpty) return const SizedBox.shrink();

    final l = L.of(context);
    final colors = context.colors;

    return InsetTile(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: EvaporateTheme.radiusPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(l.watchedFolders, style: context.text.bodyStrong),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.watchedFoldersNote, style: context.text.paragraph),
          const SizedBox(height: 10),
          for (final hint in hints) WatchedFolderRow(game: game, hint: hint),
          WatchedFoldersActions(game: game, hints: hints),
        ],
      ),
    );
  }
}
