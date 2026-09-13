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
          // Подложка обнимает клавишу, а не тянется во всю ширину: за
          // возврат отвечает одно слово в углу, а полоса на весь экран
          // выглядела заголовком раздела и обещала больше, чем несёт.
          child: Align(
            alignment: Alignment.centerLeft,
            child: GlassSurface(
              radius: EvaporateTheme.radiusSelection,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: TextButton.icon(
                onPressed: () => nav.add(const GameOpened(null)),
                style: TextButton.styleFrom(
                  // Тем же радиусом, что подложка: иначе фон, встающий под
                  // клавишей при наведении и выборе, рисует внутри мягкого
                  // угла свой острый.
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      EvaporateTheme.radiusSelection,
                    ),
                  ),
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(L.of(context).backToLibrary),
              ),
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
