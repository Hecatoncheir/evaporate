import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import 'effects/foil/foil_card.dart';
import 'game_cover.dart';
import 'library_grid_controller.dart';
import 'rise_in.dart';

/// Одна плитка сетки: она же следит за курсором и всходит при появлении.
///
/// Наведение сообщается наружу и там выбирает игру: крупный кадр наверху
/// идёт за выбором — без этого до его клавиш было бы не добраться: кадр
/// сменился бы раньше, чем рука дойдёт. Фокус при этом не трогаем — он у
/// клавиатуры и геймпада, и отбирать его курсором, лежащим над сеткой,
/// значило бы уводить набор из поиска. Первое же нажатие стрелки сведёт
/// выбор обратно к сфокусированной плитке: выбор идёт за фокусом, а не
/// наоборот.
///
/// «Под курсором» и «горит» плитка узнаёт у контроллера сама: прежде
/// каждое наведение перестраивало всю страницу — сетку, крупный кадр и
/// свет, — а следом ещё раз от выбора игры. Теперь от наведения
/// перестраиваются только те плитки, у которых эти признаки сменились.
class LibraryGridTile extends StatefulWidget {
  const LibraryGridTile({
    super.key,
    required this.controller,
    required this.game,
    required this.index,
    required this.selected,
    required this.effects,
    required this.onHover,
    required this.onOpen,
    required this.onFocused,
  });

  /// Наведение, ключи и фокусы сетки.
  final LibraryGridController controller;

  final Game game;

  /// Место в сетке: по нему считается задержка всхода.
  final int index;

  final bool selected;
  final Appearance effects;

  /// Курсор вошёл или ушёл.
  final ValueChanged<bool> onHover;

  final VoidCallback onOpen;
  final VoidCallback onFocused;

  @override
  State<LibraryGridTile> createState() => _LibraryGridTileState();
}

class _LibraryGridTileState extends State<LibraryGridTile> {
  late ({bool hovered, bool active}) _look = _lookNow();

  /// Под курсором ли плитка и горит ли она. Горит одна: под курсором, а
  /// если курсора в сетке нет — выбранная. Фольга и наклон — только у неё.
  ({bool hovered, bool active}) _lookNow() {
    final hovered = widget.controller.hoveredId;
    return (
      hovered: hovered == widget.game.id,
      active: hovered == null ? widget.selected : hovered == widget.game.id,
    );
  }

  void _onController() {
    final next = _lookNow();
    if (next != _look) setState(() => _look = next);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(LibraryGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    _look = _lookNow();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final effects = widget.effects;
    final game = widget.game;
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: RiseIn(
        enabled: effects.shows(LibraryEffect.interfaceAnimations),
        // Очередь всхода — только для первого экрана. Дальше ленивая сетка
        // строит плитки по мере прокрутки, и задержка означала бы, что
        // домотанное появляется через полсекунды после того, как человек
        // до него домотал.
        delay: widget.index < motion.staggerLimit
            ? motion.staggerAt(widget.index)
            : Duration.zero,
        child: AnimatedContainer(
          duration: motion.fast,
          curve: EvaporateMotion.ease,
          // Обложка приподнимается под курсором: в сетке одинаковых
          // прямоугольников это самый заметный способ показать, где рука, —
          // заметнее рамки.
          transform: Matrix4.translationValues(0, _look.hovered ? -7 : 0, 0),
          child: KeyedSubtree(
            // Ключ плитки: по нему рамка выбранного знает, куда перетечь.
            key: widget.controller.tileKey(game.id),
            child: FoilCard(
              active: _look.active,
              enabled: effects.libraryEffects,
              foilEnabled: effects.isOn(LibraryEffect.foil),
              tiltEnabled: effects.isOn(LibraryEffect.cardTilt),
              distortionEnabled: effects.isOn(LibraryEffect.liquidDistortion),
              child: GameCoverTile(
                focusNode: widget.controller.focusNode(game.id),
                key: ValueKey(game.id),
                game: game,
                selected: widget.selected,
                dropsEnabled: effects.shows(LibraryEffect.drops),
                portalEnabled: effects.shows(LibraryEffect.portal),
                // Рамка живёт мимо общего выключателя эффектов: она
                // показывает, где ты в сетке, а не украшает её.
                frameEnabled: effects.isOn(LibraryEffect.selectionFrame),
                onOpen: widget.onOpen,
                // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть»
                // должна работать по той игре, на которую смотришь, не
                // заходя внутрь.
                onFocused: widget.onFocused,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
