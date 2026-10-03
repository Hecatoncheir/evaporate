import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../ev/app/ev_library_hero.dart';
import 'primary_action.dart';

/// Место крупного кадра над полкой.
///
/// Кадр выбранной игры — виджет прототипа. На низком окне он имеет высоту
/// 300 точек, на высоком растёт по ступеням прототипа. До переноса полок
/// остаётся прежний порог скрытия в совсем низком окне.
class LibraryFeaturedSlot extends StatelessWidget {
  const LibraryFeaturedSlot({
    super.key,
    required this.games,
    required this.height,
  });

  /// Ниже этой высоты кадр убирается совсем. Число — от каркаса: в
  /// наименьшем окне (620 по высоте) разделу достаётся 530 точек между
  /// верхней полосой и строкой подсказок, и полосе кадра рядом с полкой
  /// там уже не место — первый ряд обложек уходил под нижний край.
  ///
  /// Страница с тех пор прокручивается целиком, и кадр можно было бы
  /// оставить везде: его домотали бы. Порог остался, потому что отвечает
  /// он за первый экран, а не за то, достижим ли кадр: открыв библиотеку,
  /// человек видит хотя бы один полный ряд обложек, а запустить игру
  /// можно и с плитки — клавишей геймпада, — и со страницы игры.
  static const heroHeight = 540.0;

  final List<Game> games;

  /// Высота места раздела между полосами, а не всей прокрутки.
  final double height;

  /// Игра для кадра: выбранная, а если её на полке нет — первая.
  Game? _featured(String? selectedId) {
    if (games.isEmpty) return null;
    final index = games.indexWhere((game) => game.id == selectedId);
    return games[index < 0 ? 0 : index];
  }

  @override
  Widget build(BuildContext context) {
    final game = _featured(
      context.select<NavigationBloc, String?>((b) => b.state.selectedGameId),
    );
    final effects = context.select<SettingsBloc, Appearance>(
      (b) => b.state.appearance,
    );
    if (game == null || height < heroHeight) return const SizedBox.shrink();
    return EvLibraryHero(
      game: game,
      sweepEnabled: effects.shows(LibraryEffect.heroSweep),
      shotsEnabled: effects.shows(LibraryEffect.shotsBackdrop),
      onOpen: () => context.read<NavigationBloc>().add(GameOpened(game.id)),
      onPrimary: () => dispatchPrimaryAction(context, game),
    );
  }
}
