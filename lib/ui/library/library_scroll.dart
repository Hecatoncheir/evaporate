import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/game.dart';
import '../../models/library_effect.dart';
import '../shell/chrome_overlap.dart';
import '../shell/chrome_scroll_view.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection.dart';
import 'library_empty_state.dart';
import 'library_featured_slot.dart';
import 'library_grid.dart';
import 'library_grid_controller.dart';
import 'library_heading.dart';
import 'library_toolbar.dart';

/// Страница библиотеки одной прокруткой: подпись, крупный кадр, полки и
/// сетка уходят вверх вместе и вместе же проходят под стеклом полос.
///
/// Прежде прокручивалась одна сетка, а всё над ней стояло на месте: под
/// верхнюю полосу не уходило ничего, и стеклу было нечего размыть, а
/// крупный кадр с полками отнимали у обложек высоту в любом положении.
/// Прижатого нет ничего: полки, до которых не домотали, догоняет фокус —
/// `Ctrl+F` и стрелка вверх из первого ряда подводят к ним сами.
///
/// Рамка выбранного стоит над всей прокруткой: сетка — сливер, и обернуть
/// её одну нечем.
class LibraryScroll extends StatelessWidget {
  const LibraryScroll({
    super.key,
    required this.grid,
    required this.games,
    required this.page,
    required this.searchFocus,
    required this.onScan,
    required this.onReturnToGames,
  });

  final LibraryGridController grid;
  final List<Game> games;

  /// Место раздела между полосами: по его высоте крупный кадр решает, каким
  /// ему быть, по ширине сетка меряет ряды.
  final Size page;

  final FocusNode searchFocus;
  final VoidCallback onScan;
  final VoidCallback onReturnToGames;

  /// Ниже этой высоты подписи не место: первый экран отдан обложкам.
  static const _headingHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select<NavigationBloc, String?>(
      (b) => b.state.selectedGameId,
    );
    final liquid = context.select<SettingsBloc, bool>(
      (b) => b.state.appearance.shows(LibraryEffect.liquidSelection),
    );
    return LiquidSelection(
      key: const ValueKey('grid-liquid'),
      targetKey: () => grid.targetKey(selectedId),
      enabled: liquid,
      color: context.colors.selection,
      radius: EvaporateTheme.radiusPanel,
      padding: const EdgeInsets.all(EvaporateSpacing.gap),
      child: ChromeScrollView(
        controller: grid.scroll,
        // Номера у диктора — только у плиток: у подписи, кадра и полок их
        // нет, и сетка считается с нуля.
        semanticChildCount: games.length,
        slivers: [
          if (page.height >= _headingHeight)
            const SliverToBoxAdapter(child: LibraryHeading()),
          SliverToBoxAdapter(
            child: LibraryFeaturedSlot(games: games, height: page.height),
          ),
          SliverToBoxAdapter(
            child: LibraryToolbar(
              searchFocus: searchFocus,
              onScan: onScan,
              onReturnToGames: onReturnToGames,
            ),
          ),
          if (games.isEmpty)
            _EmptyShelf(onScan: onScan)
          else
            LibraryGrid(controller: grid, games: games, width: page.width),
        ],
      ),
    );
  }
}

/// Пустая полка — во весь остаток видимого под полками: посередине, а не
/// прижатой к ним.
///
/// Не `SliverFillRemaining`: тот меряет содержимое собственной высотой, а
/// у абзаца, суженного до 420, она выходила вдвое ниже настоящей — полка
/// вылезала за свой низ. И «остаток» у него до края окна прокрутки, то
/// есть под строку подсказок. Построитель раскладки сливера пересобирает
/// полку на каждом кадре прокрутки: у сетки это было бы дорого, у трёх
/// клавиш с подписью — нет.
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final below = ChromeOverlap.of(context).bottom;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(
              0,
              constraints.viewportMainAxisExtent -
                  constraints.precedingScrollExtent -
                  below,
            ),
          ),
          child: LibraryEmptyState(onScan: onScan),
        ),
      ),
    );
  }
}
