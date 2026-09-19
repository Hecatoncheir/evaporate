import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/liquid_selection.dart';
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

  /// Поля сетки обложек и просвет между плитками.
  static const _padding = 64.0;
  static const _gap = 36.0;

  /// Ключи, фокусы, прокрутка и наведение: они переживают перестроение
  /// сетки, а сама сетка — нет.
  final LibraryGridController controller;

  final List<Game> games;
  final String? selectedId;
  final AppSettings effects;

  /// Крупность плиток из настроек библиотеки.
  final double scale;

  /// Выбрать игру — курсором или фокусом.
  final ValueChanged<String> onSelect;

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    // Где какая игра — чтобы ленивая сетка узнавала уже построенную плитку
    // после перестановки, а не собирала её заново.
    final indices = {for (var i = 0; i < games.length; i++) games[i].id: i};

    return LayoutBuilder(
      builder: (context, box) {
        _measure(box);
        return LiquidSelection(
          key: const ValueKey('grid-liquid'),
          targetKey: () => controller.targetKey(selectedId),
          enabled: effects.libraryEffects && effects.liquidSelectionEnabled,
          color: context.colors.selection,
          radius: EvaporateTheme.radiusPanel,
          padding: const EdgeInsets.all(7),
          child: GridView.builder(
            controller: controller.scroll,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indices[key.value] : null,
            padding: EvaporateLayout.inset(top: 24, bottom: 34),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              // По ширине, а не по числу столбцов: обложка должна остаться
              // читаемой и в узком окне, и на весь экран телевизора.
              maxCrossAxisExtent: 215 * scale,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 28,
              mainAxisSpacing: 32,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return LibraryGridTile(
                game: game,
                index: index,
                selected: game.id == selectedId,
                hovered: controller.hoveredId == game.id,
                // Фольга и наклон горят у одной плитки: под курсором,
                // а если курсора в сетке нет — у выбранной.
                active: (controller.hoveredId ?? selectedId) == game.id,
                effects: effects,
                tileKey: controller.tileKey(game.id),
                focusNode: controller.focusNode(game.id),
                onHover: (value) {
                  controller.hover(game.id, hovered: value);
                  // Наведение выбирает игру: крупный кадр наверху идёт
                  // за выбором, и без этого до его клавиш было бы не
                  // добраться — кадр сменился бы раньше, чем рука дойдёт.
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

  /// Ширина плитки нужна не только сетке: по шагу ряда страница мотает
  /// список, догоняя фокусом ещё не построенную плитку.
  void _measure(BoxConstraints box) {
    final extent = 215 * scale;
    final room = box.maxWidth - _padding;
    final columns = (room / (extent + _gap)).ceil().clamp(1, 1000);
    controller
      ..columns = columns
      ..rowStride = (room - _gap * (columns - 1)) / columns * 1.5 + 40;
  }
}
