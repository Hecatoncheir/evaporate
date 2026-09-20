import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../../models/shelf.dart';
import '../widgets/game_drop_target.dart';
import 'effects/library_atmosphere.dart';
import 'library_empty_state.dart';
import 'library_featured_slot.dart';
import 'library_grid.dart';
import 'library_grid_controller.dart';
import 'library_heading_bar.dart';
import 'library_shelf_bar.dart';

/// Сама страница библиотеки: заголовок, крупный кадр, полки и сетка.
///
/// Отдельно от `LibraryPage`, у которой на руках выбор, поиск, фокус и
/// системные окна: здесь только раскладка и то, что ей для неё нужно.
class LibraryBody extends StatelessWidget {
  const LibraryBody({
    super.key,
    required this.grid,
    required this.games,
    required this.found,
    required this.libraryIsEmpty,
    required this.shelf,
    required this.selectedId,
    required this.effects,
    required this.scale,
    required this.scanning,
    required this.searchFocus,
    required this.onShelf,
    required this.onQuery,
    required this.onReturnToGames,
    required this.onScan,
    required this.onAdd,
    required this.onSelect,
    required this.onOpen,
  });

  final LibraryGridController grid;

  /// Игры выбранной полки — то, что и показывают.
  final List<Game> games;

  /// Все найденные поиском: по ним считаются числа у полок.
  final List<Game> found;

  /// В библиотеке нет игр вовсе — это другой разговор, чем «ничего не
  /// нашлось на этой полке».
  final bool libraryIsEmpty;

  final Shelf shelf;
  final String? selectedId;
  final AppSettings effects;
  final double scale;

  /// Идёт поиск установленных игр: пока он идёт, сброс в окно перехватывает
  /// его собственное окно.
  final bool scanning;

  final FocusNode searchFocus;
  final ValueChanged<Shelf> onShelf;
  final ValueChanged<String> onQuery;
  final VoidCallback onReturnToGames;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpen;

  /// Ниже этой высоты не остаётся места и заголовку раздела.
  static const _headingHeight = 360.0;

  @override
  Widget build(BuildContext context) {
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
              if (height >= _headingHeight) const LibraryHeadingBar(),
              LibraryFeaturedSlot(
                games: games,
                selectedId: selectedId,
                effects: effects,
                height: height,
              ),
              LibraryShelfBar(
                shelf: shelf,
                found: found,
                searchFocus: searchFocus,
                onShelf: onShelf,
                onQuery: onQuery,
                onReturnToGames: onReturnToGames,
                onScan: onScan,
                onAdd: onAdd,
              ),
              Expanded(
                child: GameDropTarget(
                  enabled: !scanning,
                  child: games.isEmpty
                      ? LibraryEmptyState(
                          libraryIsEmpty: libraryIsEmpty,
                          onAdd: onAdd,
                        )
                      : LibraryGrid(
                          controller: grid,
                          games: games,
                          selectedId: selectedId,
                          effects: effects,
                          scale: scale,
                          onSelect: onSelect,
                          onOpen: onOpen,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
