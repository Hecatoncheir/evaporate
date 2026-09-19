import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import 'featured_game.dart';
import 'primary_action.dart';

/// Место крупного кадра над полкой.
///
/// Кадр выбранной игры не прячется там, где просто меньше места: ниже 760
/// точек он становится полосой и уходит совсем только тогда, когда иначе не
/// осталось бы места самой полке.
class LibraryFeaturedSlot extends StatelessWidget {
  const LibraryFeaturedSlot({
    super.key,
    required this.games,
    required this.selectedId,
    required this.effects,
    required this.height,
  });

  /// Выше этой высоты у кадра полный вид; ниже — полоса.
  static const _roomyHeight = 760.0;

  /// Ниже этой высоты кадр убирается совсем.
  static const heroHeight = 520.0;

  final List<Game> games;
  final String? selectedId;
  final AppSettings effects;

  /// Высота, доставшаяся разделу.
  final double height;

  /// Игра для кадра: выбранная, а если её на полке нет — первая.
  Game? get _featured {
    if (games.isEmpty) return null;
    final index = games.indexWhere((game) => game.id == selectedId);
    return games[index < 0 ? 0 : index];
  }

  @override
  Widget build(BuildContext context) {
    final game = _featured;
    if (game == null || height < heroHeight) return const SizedBox.shrink();
    return FeaturedGame(
      game: game,
      compact: height < _roomyHeight,
      sweepEnabled: effects.libraryEffects && effects.heroSweepEnabled,
      shotsEnabled: effects.libraryEffects && effects.shotsBackdropEnabled,
      onOpen: () => context.read<NavigationBloc>().add(GameOpened(game.id)),
      onPrimary: () => dispatchPrimaryAction(context, game),
    );
  }
}
