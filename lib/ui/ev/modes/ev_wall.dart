import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../data/sample_data.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'modes_data.dart';

/// Где стоят плитки «Стены»: `repeat(auto-fill, minmax(146px, 1fr))`,
/// ряды одной высоты, первая плитка — большая, 3 × 2 клетки (уже 900 px
/// окна — 2 × 2). Большая всегда первая, поэтому сетка не прыгает, когда
/// выбирают другую игру.
List<Rect> evWallCells({
  required double width,
  required int count,
  required bool wide,
}) {
  const gap = EvWall.gap;
  final columns = math.max(1, ((width + gap) / (EvWall.minTile + gap)).floor());
  final tile = (width - gap * (columns - 1)) / columns;
  final height = tile * 4 / 3;
  final span = math.min(columns, wide ? 3 : 2);
  Rect cell(int col, int row, {int cols = 1, int rows = 1}) => Rect.fromLTWH(
    col * (tile + gap),
    row * (height + gap),
    tile * cols + gap * (cols - 1),
    height * rows + gap * (rows - 1),
  );

  final cells = <Rect>[];
  if (count == 0) return cells;
  cells.add(cell(0, 0, cols: span, rows: 2));
  // Остальные — по порядку, мимо клеток большой.
  for (var i = 0; cells.length < count; i++) {
    final col = i % columns, row = i ~/ columns;
    if (row < 2 && col < span) continue;
    cells.add(cell(col, row));
  }
  return cells;
}

abstract final class EvWall {
  static const gap = 11.0;
  static const minTile = 146.0;
}

/// Полоса фильтров и счётчик «8 из 12».
class EvWallBar extends StatelessWidget {
  const EvWallBar({
    super.key,
    required this.filter,
    required this.onFilter,
    required this.shown,
    required this.total,
  });

  final EvWallFilter filter;
  final ValueChanged<EvWallFilter> onFilter;
  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Row(
      children: [
        for (final f in EvWallFilter.values) ...[
          if (f.index > 0) const SizedBox(width: 8),
          EvFilterChip(
            label: f.label,
            selected: f == filter,
            onTap: () => onFilter(f),
          ),
        ],
        const Spacer(),
        Text(
          '$shown из $total',
          style: ev.text.data.copyWith(fontSize: 10.5, color: ev.colors.ink4),
        ),
      ],
    );
  }
}

/// Фильтр-капсула: моноширинная подпись, выбранный — янтарный.
class EvFilterChip extends StatefulWidget {
  const EvFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<EvFilterChip> createState() => _EvFilterChipState();
}

class _EvFilterChipState extends State<EvFilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.pill,
          child: AnimatedContainer(
            duration: EvMotion.fast,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: ev.radii.bPill,
              border: Border.all(
                color: on
                    ? c.hot1.withValues(alpha: .45)
                    : _hover
                    ? c.ink4
                    : c.line,
              ),
              color: on ? c.hot1.withValues(alpha: .1) : null,
            ),
            child: Text(
              widget.label,
              style: ev.text.data.copyWith(
                fontSize: 10.5,
                letterSpacing: 10.5 * .06,
                color: on
                    ? c.hot2
                    : _hover
                    ? c.ink
                    : c.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Маленькая плитка: обложка, бейдж состояния, имя — по наведению.
class EvWallTile extends StatefulWidget {
  const EvWallTile({super.key, required this.game, required this.onTap});

  final SampleGame game;
  final VoidCallback onTap;

  @override
  State<EvWallTile> createState() => _EvWallTileState();
}

class _EvWallTileState extends State<EvWallTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final g = widget.game;
    final badge = g.badge;
    return Semantics(
      button: true,
      label: g.title,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) {
          EvSoundScope.maybeOf(context)?.play(EvVoice.tick);
          setState(() => _hover = true);
        },
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.r3,
          onFocusHighlight: (v) => setState(() => _hover = v),
          child: AnimatedContainer(
            duration: EvMotion.hover,
            curve: EvMotion.easeOut,
            transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: ev.radii.b3,
              border: Border.all(
                color: _hover ? c.hot1.withValues(alpha: .4) : c.line,
              ),
              boxShadow: _hover
                  ? const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, .6),
                        blurRadius: 38,
                        offset: Offset(0, 18),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: ev.radii.b3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EvCover(palette: g.palette, seed: g.seed),
                  const _TileShade(),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: EvCoverBadge(badge, state: g.state),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 9,
                    child: AnimatedOpacity(
                      duration: EvMotion.fast,
                      opacity: _hover ? 1 : 0,
                      child: AnimatedSlide(
                        duration: EvMotion.fast,
                        curve: EvMotion.easeOut,
                        offset: Offset(0, _hover ? 0 : .3),
                        child: Text(
                          g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ev.text.body.copyWith(
                            fontSize: 11,
                            color: c.ink,
                            shadows: const [
                              Shadow(color: Color(0xFF000000), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.wt::after`: светлая кромка сверху и тень снизу, чтобы имя читалось.
class _TileShade extends StatelessWidget {
  const _TileShade();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color.fromRGBO(0, 0, 0, .8), Color(0x00000000)],
              stops: [0, .4],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: ColoredBox(
            color: context.ev.colors.ink.withValues(alpha: .14),
          ),
        ),
      ],
    ),
  );
}

/// Большая плитка выбранной игры: кадр, чипы, название и два действия.
class EvWallFeature extends StatelessWidget {
  const EvWallFeature({
    super.key,
    required this.game,
    required this.onPlay,
    required this.onDetails,
  });

  final SampleGame game;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final pad = (window.width * .02).clamp(16.0, 22.0);
    final title = (window.width * .022).clamp(20.0, 30.0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: ev.radii.b3,
        border: Border.all(color: c.hot1.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(color: c.hot1.withValues(alpha: .24), blurRadius: 46),
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .6),
            blurRadius: 54,
            offset: Offset(0, 26),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ev.radii.b3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: _FeatureArt(game.palette, game.seed)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color.fromRGBO(6, 6, 10, .95),
                    Color.fromRGBO(6, 6, 10, .4),
                    Color(0x0006060A),
                  ],
                  stops: [.08, .46, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (label, hot) in game.chips.take(2))
                        EvChip(label, hot: hot),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    game.title,
                    style: ev.text
                        .dsp(
                          ev.text.section,
                          size: title,
                          weight: FontWeight.w800,
                          letterSpacing: title * -.02,
                        )
                        .copyWith(height: .98, color: c.ink),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      EvPlayButton(
                        label: evMainAction(game),
                        requireHold: false,
                        height: 44,
                        onLaunch: onPlay,
                      ),
                      EvGhostButton(
                        label: 'Подробнее',
                        icon: EvIcons.info,
                        height: 44,
                        onPressed: onDetails,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кадр большой плитки: `makeArt(760, 520, …, {sx: .66, sy: .36})` по
/// `background-size: cover`.
class _FeatureArt extends CustomPainter {
  _FeatureArt(this.palette, this.seed);

  final EvCoverPalette palette;
  final int seed;

  static const _scene = Size(760, 520);

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.max(size.width / _scene.width, size.height / _scene.height);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(
        (size.width - _scene.width * k) / 2,
        (size.height - _scene.height * k) / 2,
      )
      ..scale(k);
    paintKeyScene(
      canvas,
      _scene,
      palette,
      seed + 7,
      ridges: 2,
      sunX: .66,
      sunY: .36,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeatureArt old) =>
      old.palette != palette || old.seed != seed;
}
