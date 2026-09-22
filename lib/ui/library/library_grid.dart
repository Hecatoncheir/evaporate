import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection.dart';
import 'library_grid_controller.dart';
import 'library_grid_tile.dart';

/// Сетка обложек: ленивая, с рамкой выбранного и всходом первого экрана.
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({
    super.key,
    required this.controller,
    required this.games,
    required this.selectedId,
    required this.effects,
    required this.scale,
    required this.onSelect,
    required this.onOpen,
  });

  /// Ключи, фокусы, прокрутка и наведение: они переживают перестроение
  /// сетки, а сама сетка — нет.
  final LibraryGridController controller;

  final List<Game> games;
  final String? selectedId;
  final Appearance effects;

  /// Крупность плиток из настроек библиотеки.
  final double scale;

  /// Выбрать игру — курсором или фокусом.
  final ValueChanged<String> onSelect;

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    // Где какая игра — чтобы ленивая сетка узнавала уже построенную плитку
    // после перестановки, а не собирала её заново. Ключ для этого стоит на
    // самой `LibraryGridTile`: спрятанный в её `MouseRegion`, он до сетки не
    // доходил, и после отбора плитки собирались заново — всход повторялся.
    final indices = {for (var i = 0; i < games.length; i++) games[i].id: i};

    return LayoutBuilder(
      builder: (context, box) {
        _measure(box);
        return LiquidSelection(
          key: const ValueKey('grid-liquid'),
          targetKey: () => controller.targetKey(selectedId),
          enabled: effects.shows(LibraryEffect.liquidSelection),
          color: context.colors.selection,
          radius: EvaporateTheme.radiusPanel,
          padding: const EdgeInsets.all(EvaporateSpacing.gap),
          child: GridView.builder(
            controller: controller.scroll,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indices[key.value] : null,
            padding: padding,
            gridDelegate: delegateFor(scale),
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
                onHover: (value) {
                  controller.hover(game.id, hovered: value);
                  if (value && selectedId != game.id) onSelect(game.id);
                },
                onOpen: () => onOpen(game.id),
                onFocused: () => onSelect(game.id),
              );
            },
          ),
        );
      },
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
  /// список, догоняя фокусом ещё не построенную плитку.
  void _measure(BoxConstraints box) {
    final layout = layoutFor(box.maxWidth, scale);
    controller
      ..columns = layout.columns
      ..rowStride = layout.rowStride;
  }
}
