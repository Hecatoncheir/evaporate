import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/rise_in.dart';
import 'effects/foil/foil_card.dart';
import 'game_cover.dart';

/// Одна плитка сетки: она же следит за курсором и всходит при появлении.
///
/// Наведение сообщается наружу и там выбирает игру: крупный кадр наверху
/// идёт за выбором. Фокус при этом не трогаем — он у клавиатуры и
/// геймпада, и отбирать его курсором, лежащим над сеткой, значило бы
/// уводить набор из поиска. Первое же нажатие стрелки сведёт выбор обратно
/// к сфокусированной плитке: выбор идёт за фокусом, а не наоборот.
class LibraryGridTile extends StatelessWidget {
  const LibraryGridTile({
    super.key,
    required this.game,
    required this.index,
    required this.selected,
    required this.hovered,
    required this.active,
    required this.effects,
    required this.tileKey,
    required this.focusNode,
    required this.onHover,
    required this.onOpen,
    required this.onFocused,
  });

  final Game game;

  /// Место в сетке: по нему считается задержка всхода.
  final int index;

  final bool selected;
  final bool hovered;

  /// Под курсором, а если курсора в сетке нет — выбранная: фольга и
  /// наклон горят только у одной плитки.
  final bool active;
  final AppSettings effects;

  /// Ключ плитки: по нему рамка выбранного знает, куда перетечь.
  final GlobalKey tileKey;

  final FocusNode focusNode;

  /// Курсор вошёл или ушёл.
  final ValueChanged<bool> onHover;

  final VoidCallback onOpen;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return MouseRegion(
      key: ValueKey(game.id),
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: RiseIn(
        enabled: effects.libraryEffects && effects.interfaceAnimationsEnabled,
        // Очередь всхода — только для первого экрана. Дальше ленивая сетка
        // строит плитки по мере прокрутки, и задержка означала бы, что
        // домотанное появляется через полсекунды после того, как человек
        // до него домотал.
        delay: index < motion.staggerLimit
            ? motion.staggerAt(index)
            : Duration.zero,
        child: AnimatedContainer(
          duration: motion.fast,
          curve: EvaporateMotion.ease,
          // Обложка приподнимается под курсором: в сетке одинаковых
          // прямоугольников это самый заметный способ показать, где рука, —
          // заметнее рамки.
          transform: Matrix4.translationValues(0, hovered ? -7 : 0, 0),
          child: KeyedSubtree(
            key: tileKey,
            child: FoilCard(
              active: active,
              enabled: effects.libraryEffects,
              foilEnabled: effects.foilEnabled,
              tiltEnabled: effects.cardTiltEnabled,
              distortionEnabled: effects.liquidDistortionEnabled,
              child: GameCoverTile(
                focusNode: focusNode,
                key: ValueKey(game.id),
                game: game,
                selected: selected,
                dropsEnabled: effects.libraryEffects && effects.dropsEnabled,
                portalEnabled: effects.libraryEffects && effects.portalEnabled,
                // Рамка живёт мимо общего выключателя эффектов: она
                // показывает, где ты в сетке, а не украшает её.
                frameEnabled: effects.selectionFrameEnabled,
                onOpen: onOpen,
                // Выбор идёт за фокусом, а не за нажатием: кнопка «Играть»
                // должна работать по той игре, на которую смотришь, не
                // заходя внутрь.
                onFocused: onFocused,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
