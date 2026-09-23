import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../widgets/game_drop_target.dart';
import 'effects/library_atmosphere.dart';
import 'library_empty_state.dart';
import 'library_featured_slot.dart';
import 'library_grid.dart';
import 'library_grid_controller.dart';
import 'library_heading.dart';
import 'toolbar.dart';

/// Сама страница библиотеки: заголовок, крупный кадр, полки и сетка.
///
/// Отдельно от `LibraryPage`, у которой на руках выбор, поиск, фокус и
/// системные окна: здесь только раскладка. Выбор, облик и крупность
/// листья берут у блоков сами — прежде всё это шло сюда параметрами, а
/// само тело читало из четырнадцати один облик.
class LibraryBody extends StatelessWidget {
  const LibraryBody({
    super.key,
    required this.grid,
    required this.games,
    required this.searchFocus,
    required this.scanning,
    required this.onScan,
    required this.onReturnToGames,
  });

  final LibraryGridController grid;

  /// Игры выбранной полки — то, что и показывают. Считает их страница:
  /// по ним же она чинит выбор и возвращает фокус.
  final List<Game> games;

  final FocusNode searchFocus;

  /// Идёт поиск установленных игр: пока он идёт, сброс в окно перехватывает
  /// его собственное окно.
  final bool scanning;

  /// Поиск установленных игр держит флаг [scanning] страницы — поэтому он
  /// её, а не клавиши, которая его зовёт.
  final VoidCallback onScan;

  final VoidCallback onReturnToGames;

  /// Ниже этой высоты не остаётся места и заголовку раздела.
  static const _headingHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final effects = context.select<SettingsBloc, Appearance>(
      (b) => b.state.appearance,
    );
    final selectedId = context.select<NavigationBloc, String?>(
      (b) => b.state.selectedGameId,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return LibraryAtmosphere(
          enabled: effects.libraryEffects,
          particlesEnabled: effects.isOn(LibraryEffect.particles),
          ambientEnabled: effects.isOn(LibraryEffect.ambient),
          targetKey: () => grid.targetKey(selectedId),
          child: Column(
            children: [
              if (height >= _headingHeight) const ConceptLibraryHeading(),
              LibraryFeaturedSlot(games: games, height: height),
              LibraryToolbar(
                searchFocus: searchFocus,
                onScan: onScan,
                onReturnToGames: onReturnToGames,
              ),
              Expanded(
                child: GameDropTarget(
                  enabled: !scanning,
                  child: games.isEmpty
                      ? const LibraryEmptyState()
                      : LibraryGrid(controller: grid, games: games),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
