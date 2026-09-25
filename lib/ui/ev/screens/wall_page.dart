import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../design/tokens.dart';
import '../modes/ev_wall.dart';
import '../modes/modes_data.dart';

/// «Стена» — плотная сетка обложек. Выбранная игра стоит первой большой
/// плиткой; фильтры и счётчик — в шапке.
class WallPage extends StatefulWidget {
  const WallPage({
    super.key,
    required this.games,
    required this.selected,
    required this.onPlay,
    required this.onOpen,
  });

  final List<SampleGame> games;

  /// Игра, выбранная сначала, — та, что в герое.
  final SampleGame selected;

  /// «Играть» или «К загрузкам» у большой плитки.
  final ValueChanged<SampleGame> onPlay;

  /// «Подробнее» — карточка игры.
  final ValueChanged<SampleGame> onOpen;

  @override
  State<WallPage> createState() => _WallPageState();
}

class _WallPageState extends State<WallPage> {
  var _filter = EvWallFilter.all;
  late SampleGame _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final list = _filter.of(widget.games);
    // Выбранная ушла из фильтра — большой становится первая.
    final selected = list.contains(_selected) ? _selected : list.firstOrNull;
    final ordered = [?selected, ...list.where((g) => g != selected)];
    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        gutter,
        chrome.top + gutter,
        gutter,
        26 + chrome.bottom,
      ),
      children: [
        EvWallBar(
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
          shown: list.length,
          total: widget.games.length,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final cells = evWallCells(
              width: box.maxWidth,
              count: ordered.length,
              wide: window.width > 900,
            );
            final height = cells.fold(
              0.0,
              (h, r) => r.bottom > h ? r.bottom : h,
            );
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (i, g) in ordered.indexed)
                    Positioned.fromRect(
                      key: ValueKey(g.title),
                      rect: cells[i],
                      child: i == 0
                          ? EvWallFeature(
                              game: g,
                              onPlay: () => widget.onPlay(g),
                              onDetails: () => widget.onOpen(g),
                            )
                          : EvWallTile(
                              game: g,
                              onTap: () => setState(() => _selected = g),
                            ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
