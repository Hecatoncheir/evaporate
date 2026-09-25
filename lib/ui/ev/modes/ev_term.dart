import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';
import 'modes_data.dart';

/// Столбцы таблицы: ширина в пикселях или доля оставшегося места.
/// Уже 1000 px окна жанр, размер и последний запуск уходят.
typedef _Col = ({double? width, int flex, bool right});

List<_Col> _columns(bool wide) => wide
    ? const [
        (width: 22, flex: 0, right: false), // статус
        (width: 26, flex: 0, right: false), // обложка
        (width: null, flex: 22, right: false), // название
        (width: null, flex: 10, right: false), // жанр
        (width: 68, flex: 0, right: false), // версия
        (width: 82, flex: 0, right: true), // размер
        (width: 62, flex: 0, right: true), // часы
        (width: 104, flex: 0, right: false), // последний запуск
        (width: 34, flex: 0, right: false), // запуск
      ]
    : const [
        (width: 22, flex: 0, right: false),
        (width: 26, flex: 0, right: false),
        (width: null, flex: 20, right: false),
        (width: 74, flex: 0, right: false),
        (width: 62, flex: 0, right: true),
        (width: 34, flex: 0, right: false),
      ];

/// Ряд ячеек по сетке столбцов, с зазором 12 px.
class _Cells extends StatelessWidget {
  const _Cells({required this.wide, required this.cells});

  final bool wide;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final cols = _columns(wide);
    return Row(
      children: [
        for (final (i, col) in cols.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          if (col.width == null)
            Expanded(flex: col.flex, child: cells[i])
          else
            SizedBox(
              width: col.width,
              child: Align(
                alignment: col.right
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: cells[i],
              ),
            ),
        ],
      ],
    );
  }
}

/// Шапка таблицы: заголовки сортируют, активный — янтарный со стрелкой.
class EvTermHead extends StatelessWidget {
  const EvTermHead({
    super.key,
    required this.wide,
    required this.sort,
    required this.ascending,
    required this.onSort,
  });

  final bool wide;
  final EvTermSort sort;
  final bool ascending;
  final ValueChanged<EvTermSort> onSort;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    Widget head(EvTermSort s) => _SortButton(
      sort: s,
      active: s == sort,
      ascending: ascending,
      onTap: onSort,
    );
    final version = Text(
      'ВЕРСИЯ',
      style: ev.text.data.copyWith(
        fontSize: 8.5,
        letterSpacing: 8.5 * .14,
        color: ev.colors.ink4,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: ev.colors.ink.withValues(alpha: .022),
        border: Border(bottom: BorderSide(color: ev.colors.lineSoft)),
      ),
      child: SizedBox(
        height: 16,
        child: _Cells(
          wide: wide,
          cells: wide
              ? [
                  const SizedBox(),
                  const SizedBox(),
                  head(EvTermSort.name),
                  head(EvTermSort.genre),
                  version,
                  head(EvTermSort.size),
                  head(EvTermSort.hours),
                  head(EvTermSort.last),
                  const SizedBox(),
                ]
              : [
                  const SizedBox(),
                  const SizedBox(),
                  head(EvTermSort.name),
                  version,
                  head(EvTermSort.hours),
                  const SizedBox(),
                ],
        ),
      ),
    );
  }
}

class _SortButton extends StatefulWidget {
  const _SortButton({
    required this.sort,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final EvTermSort sort;
  final bool active;
  final bool ascending;
  final ValueChanged<EvTermSort> onTap;

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final color = widget.active
        ? c.hot2
        : _hover
        ? c.ink2
        : c.ink4;
    final arrow = widget.active ? (widget.ascending ? ' ▴' : ' ▾') : '';
    return Semantics(
      button: true,
      selected: widget.active,
      label: 'Сортировать: ${widget.sort.label}',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: () => widget.onTap(widget.sort),
          child: Text(
            '${widget.sort.label.toUpperCase()}$arrow',
            // Как в браузере: подпись шире столбца выходит в зазор, а не
            // обрезается многоточием.
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: ev.text.data.copyWith(
              fontSize: 8.5,
              letterSpacing: 8.5 * .14,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка таблицы. Свет скупой: только выделенная строка и точки статуса.
class EvTermLine extends StatefulWidget {
  const EvTermLine({
    super.key,
    required this.row,
    required this.wide,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
  });

  final EvTermRow row;
  final bool wide;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPlay;

  @override
  State<EvTermLine> createState() => _EvTermLineState();
}

class _EvTermLineState extends State<EvTermLine> {
  bool _hover = false;

  /// Точка статуса: играли — зелёная, качается — янтарная, остальное —
  /// тусклая.
  Color _dot(EvColors c) {
    final g = widget.row.game;
    return switch (g.state) {
      EvGameState.ready => widget.row.facts.hours > 0 ? EvColors.ok : c.ink4,
      EvGameState.downloading => c.hot2,
      EvGameState.queued => c.ink4,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final r = widget.row;
    final g = r.game;
    final on = widget.selected;
    final mono = ev.text.data.copyWith(
      fontSize: 11,
      color: on ? c.ink : c.ink3,
    );
    final dot = _dot(c);
    final status = Center(
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dot,
          boxShadow: [BoxShadow(color: dot, blurRadius: 7)],
        ),
      ),
    );
    final cover = Container(
      width: 22,
      height: 29,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: EvCover(palette: g.palette, seed: g.seed),
      ),
    );
    final name = Text(
      g.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ev.text.body.copyWith(fontSize: 12.5, color: on ? c.ink : c.ink2),
    );
    final size = Text(
      r.sizeGb > 0
          ? '${r.sizeGb.toStringAsFixed(1).replaceAll('.', ',')} ГБ'
          : '—',
      style: mono,
    );
    final hours = Text(
      r.facts.hours > 0 ? '${r.facts.hours} ч' : '—',
      style: mono,
    );
    final go = AnimatedOpacity(
      duration: EvMotion.fast,
      opacity: on || _hover ? 1 : 0,
      child: EvFocusable(
        onActivate: widget.onPlay,
        child: Semantics(
          button: true,
          label: '${evMainAction(g)}: ${g.title}',
          excludeSemantics: true,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(child: EvIcon(EvIcons.play, size: 13, color: c.hot2)),
          ),
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) {
        EvSoundScope.maybeOf(context)?.play(EvVoice.tick);
        setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: Semantics(
          selected: on,
          label: g.title,
          child: AnimatedContainer(
            duration: EvMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: on
                  ? c.hot1.withValues(alpha: .09)
                  : _hover
                  ? c.ink.withValues(alpha: .035)
                  : null,
              border: Border(
                left: BorderSide(
                  color: on ? c.hot1 : const Color(0x00000000),
                  width: 2,
                ),
                bottom: BorderSide(color: c.lineSoft),
              ),
            ),
            child: _Cells(
              wide: widget.wide,
              cells: widget.wide
                  ? [
                      status,
                      cover,
                      name,
                      Text(g.genre, maxLines: 1, style: mono),
                      Text(r.version, style: mono),
                      size,
                      hours,
                      Text(r.facts.lastAgo, maxLines: 1, style: mono),
                      go,
                    ]
                  : [
                      status,
                      cover,
                      name,
                      Text(r.version, style: mono),
                      hours,
                      go,
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
