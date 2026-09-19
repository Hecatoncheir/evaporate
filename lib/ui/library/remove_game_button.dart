import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'remove_game_dialog.dart';

/// «Убрать из библиотеки» внизу страницы игры.
///
/// Стоит последней и в углу: действие необратимое, и предлагать его наравне
/// с «Играть» незачем. Спрашивает всегда — и отдельно о том, стирать ли
/// файлы.
class RemoveGameButton extends StatelessWidget {
  const RemoveGameButton({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _remove(context),
        style: context.buttons.dangerText,
        icon: const Icon(Icons.delete_outline, size: 17),
        label: Text(L.of(context).removeFromLibrary),
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
