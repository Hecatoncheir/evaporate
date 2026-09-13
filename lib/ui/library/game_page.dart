import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/spatial_surface.dart';

import 'game_detail.dart';
import '../../l10n/app_localizations.dart';

/// Страница игры поверх сетки: заголовок с возвратом и карточка под ним.
class GamePage extends StatelessWidget {
  const GamePage({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: GlassSurface(
            radius: EvaporateTheme.radiusPanel,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => nav.add(const GameOpened(null)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(L.of(context).backToLibrary),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GameDetail(key: ValueKey(game.id), game: game),
        ),
      ],
    );
  }
}
