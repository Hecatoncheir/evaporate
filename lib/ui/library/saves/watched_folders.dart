import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/saves/save_path_finder.dart';
import '../../theme.dart';

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

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        border: Border.all(color: colors.outline),
      ),
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
          Text(
            l.watchedFoldersNote,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final hint in hints) _hintRow(context, hint),
          _footer(context, hints),
        ],
      ),
    );
  }

  /// Одна подсказка: путь, сколько файлов в нём изменилось, и «Добавить».
  Widget _hintRow(BuildContext context, SavePathSuggestion hint) {
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
                  style: const TextStyle(
                    fontFamily: EvaporateTheme.monoFontFamily,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.watchedFilesChanged(hint.fileCount),
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

  /// Отказ от всех подсказок и, когда их несколько, согласие со всеми.
  Widget _footer(BuildContext context, List<SavePathSuggestion> hints) {
    final l = L.of(context);
    final saves = context.read<SavesBloc>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => saves.add(SaveHintsDismissed(game.id)),
          child: Text(l.notThis),
        ),
        const SizedBox(width: 6),
        if (hints.length > 1)
          FilledButton(
            onPressed: () =>
                saves.add(SaveHintsAccepted(game: game, suggestions: hints)),
            child: Text(l.addAll),
          ),
      ],
    );
  }
}
