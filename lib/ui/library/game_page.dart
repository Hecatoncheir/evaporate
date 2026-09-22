import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import 'back_to_library_button.dart';
import 'detail/cover_backdrop.dart';
import 'game_detail.dart';

/// Страница игры поверх сетки: заголовок с возвратом и карточка под ним.
class GamePage extends StatelessWidget {
  const GamePage({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final backdrop = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.appearance.isOn(LibraryEffect.coverBackdrop),
    );
    return Stack(
      children: [
        // Под всей страницей, включая полосу возврата: фон отвечает на
        // «чья это страница» раньше, чем человек дочитает название.
        Positioned.fill(
          child: CoverBackdrop(game: game, enabled: backdrop),
        ),
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: BackToLibraryButton(),
            ),
            Expanded(
              child: GameDetail(key: ValueKey(game.id), game: game),
            ),
          ],
        ),
      ],
    );
  }
}
