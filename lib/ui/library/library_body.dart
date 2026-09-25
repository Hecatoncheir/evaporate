import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../widgets/game_drop_target.dart';
import 'effects/library_atmosphere.dart';
import 'library_grid_controller.dart';
import 'library_scroll.dart';

/// Сама страница библиотеки: фон, приёмник броска и одна прокрутка.
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

  @override
  Widget build(BuildContext context) {
    final effects = context.select<SettingsBloc, Appearance>(
      (b) => b.state.appearance,
    );
    final selectedId = context.select<NavigationBloc, String?>(
      (b) => b.state.selectedGameId,
    );
    // Приёмник броска — над всей страницей: бросают туда, куда смотрят, а
    // смотрят теперь и на крупный кадр, и на полки. Пока идёт поиск
    // установленных игр, он молчит: папку в окно поиска бросают ради
    // сужения поиска, а не чтобы добавить её одной игрой.
    return LayoutBuilder(
      builder: (context, box) => LibraryAtmosphere(
        enabled: effects.libraryEffects,
        particlesEnabled: effects.isOn(LibraryEffect.particles),
        ambientEnabled: effects.isOn(LibraryEffect.ambient),
        targetKey: () => grid.targetKey(selectedId),
        child: GameDropTarget(
          enabled: !scanning,
          child: LibraryScroll(
            grid: grid,
            games: games,
            page: box.biggest,
            searchFocus: searchFocus,
            onScan: onScan,
            onReturnToGames: onReturnToGames,
          ),
        ),
      ),
    );
  }
}
