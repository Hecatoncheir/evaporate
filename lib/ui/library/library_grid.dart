import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../theme.dart';
import 'library_grid_controller.dart';
import 'library_grid_tile.dart';

/// Сетка обложек: ленивая, со всходом первого экрана.
///
/// Это сливер, а не своя прокрутка: сетка — часть страницы и уходит вверх
/// вместе с подписью, крупным кадром и полками (`LibraryScroll`). Рамка
/// выбранного поэтому тоже стоит над всей страницей, а не над сеткой.
///
/// Выбор, облик и крупность плиток сетка берёт у блоков сама, а выбирают и
/// открывают игру плитки: прежде «открыть» шло сюда пятым звеном от
/// страницы, и ни одному звену посередине не было нужно.
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({
    super.key,
    required this.controller,
    required this.games,
    required this.width,
  });

  /// Ключи, фокусы, прокрутка и наведение: они переживают перестроение
  /// сетки, а сама сетка — нет.
  final LibraryGridController controller;

  final List<Game> games;

  /// Ширина страницы. Замер берёт её снаружи: построитель раскладки
  /// у сливера пересобирал бы сетку на каждый кадр прокрутки.
  final double width;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select<NavigationBloc, String?>(
      (b) => b.state.selectedGameId,
    );
    final effects = context.select<SettingsBloc, Appearance>(
      (b) => b.state.appearance,
    );
    _measure(width, effects.libraryScale);
    // Где какая игра — чтобы ленивая сетка узнавала уже построенную плитку
    // после перестановки, а не собирала её заново. Ключ для этого стоит на
    // самой `LibraryGridTile`: спрятанный в её `MouseRegion`, он до сетки не
    // доходил, и после отбора плитки собирались заново — всход повторялся.
    final indices = {for (var i = 0; i < games.length; i++) games[i].id: i};

    int? indexOf(Key key) =>
        key is ValueKey<String> ? indices[key.value] : null;

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid.builder(
        key: controller.gridKey,
        findChildIndexCallback: indexOf,
        gridDelegate: delegateFor(effects.libraryScale),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return LibraryGridTile(
            key: ValueKey(game.id),
            game: game,
            index: index,
            controller: controller,
            selected: game.id == selectedId,
            effects: effects,
          );
        },
      ),
    );
  }

  /// Поля сетки: по бокам — поле страницы, воздух сверху и снизу.
  static final padding = EvaporateLayout.inset(
    top: EvaporateSpacing.wide,
    bottom: EvaporateSpacing.vast,
  );

  /// Раскладка сетки при крупности [scale].
  ///
  /// По ширине, а не по числу столбцов: обложка должна остаться читаемой и
  /// в узком окне, и на весь экран телевизора.
  static SliverGridDelegateWithMaxCrossAxisExtent delegateFor(double scale) =>
      SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 215 * scale,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 28,
        mainAxisSpacing: 32,
      );

  /// Сколько столбцов и какой шаг ряда у сетки шириной [width].
  ///
  /// Спрашиваем тот же делегат, который раскладывает сетку, а не считаем
  /// своими числами: прежняя своя арифметика брала поля 64 и просвет 36
  /// вместо 56 и 28 и расходилась со столбцами на каждой четвёртой ширине
  /// — при 1280 пять вместо шести. По этим числам страница догоняет
  /// фокусом ещё не построенную плитку, и возврат из игры в длинной
  /// библиотеке прыгал мимо.
  static ({int columns, double rowStride}) layoutFor(
    double width,
    double scale,
  ) {
    final layout = delegateFor(scale).getLayout(
      SliverConstraints(
        axisDirection: AxisDirection.down,
        growthDirection: GrowthDirection.forward,
        userScrollDirection: ScrollDirection.idle,
        scrollOffset: 0,
        precedingScrollExtent: 0,
        overlap: 0,
        remainingPaintExtent: double.infinity,
        crossAxisExtent: width - padding.horizontal,
        crossAxisDirection: AxisDirection.right,
        viewportMainAxisExtent: double.infinity,
        remainingCacheExtent: double.infinity,
        cacheOrigin: 0,
      ),
    ) as SliverGridRegularTileLayout;
    return (columns: layout.crossAxisCount, rowStride: layout.mainAxisStride);
  }

  /// Ширина плитки нужна не только сетке: по шагу ряда страница мотает
  /// себя, догоняя фокусом ещё не построенную плитку.
  void _measure(double width, double scale) {
    final layout = layoutFor(width, scale);
    controller
      ..columns = layout.columns
      ..rowStride = layout.rowStride;
  }
}
