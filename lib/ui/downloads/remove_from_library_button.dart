import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../library/remove_game_dialog.dart';
import '../theme.dart';
import '../widgets/hover_builder.dart';

/// Убрать игру из списка — то есть из библиотеки.
///
/// Приглушена, пока на неё не навели: рядом с ней плашку тащат мышью, и
/// тревожный цвет во весь список спорил бы с тем, ради чего список
/// заведён.
class RemoveFromLibraryButton extends StatelessWidget {
  const RemoveFromLibraryButton({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HoverBuilder(
      builder: (context, hovered, _) => IconButton(
        onPressed: () => _remove(context),
        icon: const Icon(Icons.close_rounded, size: EvaporateIconSize.key),
        tooltip: L.of(context).removeFromLibrary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        color: hovered ? colors.danger : colors.textSecondary,
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final choice = await askRemoveGame(context, game);
    if (choice == null) return;
    library.add(
      GameRemoved(game, deleteFiles: choice == RemoveChoice.withFiles),
    );
  }
}
