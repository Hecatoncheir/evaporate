import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../modes/ev_term.dart';
import '../modes/modes_data.dart';
import '../util/plural.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_surfaces.dart';

/// «Терминал» — моноширинная таблица библиотеки. Любой столбец сортирует,
/// строки ходят `↑` `↓`, `Enter` запускает.
class TermPage extends StatefulWidget {
  const TermPage({super.key, required this.games, required this.onPlay});

  final List<SampleGame> games;

  /// `Enter` и значок в строке: играть или в загрузки.
  final ValueChanged<SampleGame> onPlay;

  /// Уже этого окна жанр, размер и последний запуск уходят.
  static const wideFrom = 1000.0;

  @override
  State<TermPage> createState() => _TermPageState();
}

class _TermPageState extends State<TermPage> {
  // Сначала — от последней запущенной. В прототипе «по убыванию» здесь
  // значило «от давней»: первыми шли игры, которые ни разу не запускали.
  var _sort = EvTermSort.last;
  var _ascending = false;
  SampleGame? _selected;
  final _selectedKey = GlobalKey();

  List<EvTermRow> get _rows =>
      evTermRows(widget.games, _sort, ascending: _ascending);

  void _onSort(EvTermSort sort) => setState(() {
    // Повторный клик переворачивает; новый столбец начинает с «А»
    // у текста и с большего у чисел.
    _ascending = sort == _sort ? !_ascending : sort.text;
    _sort = sort;
  });

  /// Выделенная строка; пока ничего не выбрано — первая.
  int _at(List<EvTermRow> rows) =>
      _selected == null ? 0 : rows.indexWhere((r) => r.game == _selected);

  void _move(List<EvTermRow> rows, int by) {
    final next = (_at(rows) + by).clamp(0, rows.length - 1);
    EvSoundScope.maybeOf(context)?.play(EvVoice.tick);
    setState(() => _selected = rows[next].game);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row == null || !row.mounted) return;
      // Строка доезжает до края, к которому шли, а не прыгает наверх.
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: by > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final rows = _rows;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(rows, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(rows, -1);
    } else if (key == LogicalKeyboardKey.enter && event is KeyDownEvent) {
      widget.onPlay(rows[_at(rows)].game);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final wide = window.width >= TermPage.wideFrom;
    final rows = _rows;
    final selected = rows[_at(rows)].game;
    final games = widget.games.length;
    final ready = widget.games
        .where((g) => g.state == EvGameState.ready)
        .length;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListView(
        primary: true,
        padding: EdgeInsets.fromLTRB(
          gutter,
          chrome.top + gutter,
          gutter,
          26 + chrome.bottom,
        ),
        children: [
          Text(
            '[ 02 / БИБЛИОТЕКА ]',
            style: ev.text.data.copyWith(
              fontSize: 9,
              letterSpacing: 9 * .2,
              color: c.hot1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              EvBigNumber(
                '$games',
                unit:
                    '${ruPlural(games, 'игра', 'игры', 'игр')} · '
                    '$ready установлено',
                size: (window.width * .03).clamp(24.0, 34.0),
              ),
              const Spacer(),
              Text(
                '↑↓ строка · Enter запустить · заголовок сортирует',
                style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: ev.radii.b3,
              border: Border.all(color: c.lineSoft),
            ),
            child: ClipRRect(
              borderRadius: ev.radii.b3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EvTermHead(
                    wide: wide,
                    sort: _sort,
                    ascending: _ascending,
                    onSort: _onSort,
                  ),
                  for (final r in rows)
                    EvTermLine(
                      key: r.game == selected
                          ? _selectedKey
                          : ValueKey(r.game.title),
                      row: r,
                      wide: wide,
                      selected: r.game == selected,
                      onSelect: () => setState(() => _selected = r.game),
                      onPlay: () => widget.onPlay(r.game),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
