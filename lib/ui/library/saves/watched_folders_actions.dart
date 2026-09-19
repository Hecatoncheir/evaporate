import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/saves/save_path_finder.dart';

/// Отказ от всех подсказок и, когда их несколько, согласие со всеми.
class WatchedFoldersActions extends StatelessWidget {
  const WatchedFoldersActions({
    super.key,
    required this.game,
    required this.hints,
  });

  final Game game;
  final List<SavePathSuggestion> hints;

  @override
  Widget build(BuildContext context) {
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
